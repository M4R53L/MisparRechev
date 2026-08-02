import Foundation
import SwiftUI
import UIKit

/// Where a shown result came from: a live fetch, or a stored offline snapshot
/// (with the date it was saved). Drives the "מוצג מידע שמור" banner.
enum DataFreshness: Equatable {
    case live
    case snapshot(Date)
}

/// UI state machine for the lookup flow.
enum LookupState: Equatable {
    case empty
    case loading
    case loaded(LookupResult, DataFreshness)
    case error(VehicleError)
}

@Observable
final class SearchViewModel {
    /// The app's live instance — `MisparRechevApp` renders it, and out-of-app
    /// entry points (App Shortcut intent, deep links) drive the UI through it.
    /// Tests and previews construct their own instances.
    static let shared = SearchViewModel()

    /// Current plate input as a raw string (digits only on screen).
    var plateInput: String = "" {
        didSet {
            // Only reassign when something actually needs removing (non-digits or
            // >8 chars). Avoids any write-back feedback during normal typing.
            let filtered = String(plateInput.filter { $0.isNumber }.prefix(8))
            if filtered != plateInput { plateInput = filtered }
        }
    }

    private(set) var state: LookupState = .empty
    private(set) var history: SearchHistoryStore
    private(set) var snapshots: SnapshotStore
    private(set) var myCar: MyCarStore

    /// True right after a *scanned* plate couldn't be looked up because the
    /// network is down (and no snapshot exists): the search screen shows a
    /// short notice instead of the error screen — capturing the number must
    /// not depend on the network. Cleared by the next search or reset.
    private(set) var scanOfflineNotice = false

    private let service: VehicleService
    private let defaults: UserDefaults
    private var inflight: Task<Void, Never>?

    init(
        service: VehicleService = VehicleService(),
        history: SearchHistoryStore = .load(),
        defaults: UserDefaults = .standard,
        snapshots: SnapshotStore = .load(),
        myCar: MyCarStore = .load()
    ) {
        self.service = service
        self.history = history
        self.defaults = defaults
        self.snapshots = snapshots
        self.myCar = myCar
    }

    /// The parsed plate number, or `nil` when input is not 6–8 digits.
    var validatedPlate: Int? {
        let digits = plateInput.filter { $0.isNumber }
        guard (6...8).contains(digits.count), let value = Int(digits) else {
            return nil
        }
        return value
    }

    var canSearch: Bool { validatedPlate != nil }
    var isLoading: Bool { if case .loading = state { return true } else { return false } }

    /// Kick off a lookup. Safe to call repeatedly; cancels any in-flight task.
    func search() {
        runSearch(fromScan: false)
    }

    /// Scan-entry search: fills the field, then looks up. An offline failure
    /// with no saved snapshot returns to the search screen — number kept in
    /// the field, `scanOfflineNotice` shown — instead of the error screen.
    func searchFromScan(plate: String) {
        plateInput = plate // didSet re-sanitizes to digits
        runSearch(fromScan: true)
    }

    private func runSearch(fromScan: Bool) {
        scanOfflineNotice = false
        guard let plate = validatedPlate else {
            state = .error(.invalidPlate)
            return
        }
        inflight?.cancel()
        state = .loading

        inflight = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await self.service.lookup(plate: plate)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.apply(result, for: plate)
                }
            } catch let error as VehicleError {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    // Offline fallback: when the network failed and a snapshot
                    // exists for this plate, show the saved data with a note
                    // instead of the error screen.
                    if case .network = error,
                       let snap = self.snapshots.snapshot(for: plate) {
                        self.state = .loaded(snap.result, .snapshot(snap.savedAt))
                        self.copyPlateToClipboard(plate)
                    } else if fromScan, case .network = error {
                        // The scan already did its job — the number is in the
                        // field. Land back on the search screen with a notice
                        // rather than a full error screen.
                        self.scanOfflineNotice = true
                        self.state = .empty
                    } else {
                        self.state = .error(error)
                    }
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.state = .error(.server(String(describing: error)))
                }
            }
        }
    }

    /// Applies a fresh (live) result: state, search history, offline snapshot.
    @MainActor
    private func apply(_ result: LookupResult, for plate: Int) {
        state = .loaded(result, .live)
        copyPlateToClipboard(plate)
        history = history.recording(
            plate: plate,
            manufacturer: result.vehicle.manufacturer,
            model: result.vehicle.model,
            year: result.vehicle.year)
        history.save(defaults: defaults)
        snapshots = snapshots.saving(result, for: plate)
        snapshots.save()
    }

    /// Every successfully shown lookup puts the plate on the clipboard,
    /// ready to paste elsewhere (typed searches and camera scans alike).
    private func copyPlateToClipboard(_ plate: Int) {
        UIPasteboard.general.string = String(plate)
    }

    /// Re-run a lookup for a plate tapped in history.
    func search(plate: Int) {
        plateInput = String(plate)
        search()
    }

    /// History-tap path (stale-while-revalidate): when a snapshot exists, show
    /// it instantly and revalidate live in the background — a live success
    /// replaces the screen, any live failure keeps the snapshot. Without a
    /// snapshot this is a plain `search(plate:)`.
    func searchFromHistory(plate: Int) {
        guard let snap = snapshots.snapshot(for: plate) else {
            search(plate: plate)
            return
        }
        inflight?.cancel()
        scanOfflineNotice = false
        plateInput = String(plate)
        state = .loaded(snap.result, .snapshot(snap.savedAt))
        copyPlateToClipboard(plate)

        inflight = Task { [weak self] in
            guard let self else { return }
            guard let result = try? await self.service.lookup(plate: plate) else { return }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.apply(result, for: plate)
            }
        }
    }

    /// Clear back to the empty/hero state.
    func reset() {
        inflight?.cancel()
        scanOfflineNotice = false
        plateInput = ""
        state = .empty
    }

    /// Back-navigation from the result screen: returns to the search screen
    /// but keeps the plate in the field (unlike `reset()`, which clears it).
    func goBack() {
        inflight?.cancel()
        scanOfflineNotice = false
        state = .empty
    }

    // MARK: - My car (pinned)

    var pinnedPlate: Int? { myCar.car?.plate }

    func isPinned(_ plate: Int) -> Bool { myCar.car?.plate == plate }

    /// Pins the currently shown vehicle as "הרכב שלי": seeds its status from
    /// the on-screen result, asks for notification permission, and schedules
    /// the test-expiry reminders.
    func pinCurrentCar() {
        guard case .loaded(let result, _) = state else { return }
        let vehicle = result.vehicle
        let title = [vehicle.model ?? vehicle.manufacturer, vehicle.year]
            .compactMap { $0 }.joined(separator: " • ")
        myCar = myCar.pinning(
            plate: vehicle.mispar_rechev,
            title: title.isEmpty ? String(vehicle.mispar_rechev) : title,
            tokefDt: vehicle.tokef_dt,
            recallIDs: result.recalls.compactMap { $0.RECALL_ID })
        myCar.save()
        Task { [weak self] in
            await MyCarRefresher.shared.requestAuthorization()
            MyCarRefresher.shared.applyPinned(result: result)
            guard let self else { return }
            await MainActor.run { self.reloadMyCar() }
        }
    }

    func unpinCar() {
        myCar = myCar.unpinning()
        myCar.save()
        MyCarRefresher.shared.cancelAllMyCarNotifications()
    }

    /// Re-reads the shared store after out-of-band writes (background refresh,
    /// pin-time seeding) so the UI reflects the latest status.
    func reloadMyCar() {
        myCar = .load()
    }

    func removeHistory(plate: Int) {
        history = history.removing(plate: plate)
        history.save(defaults: defaults)
    }

    func clearHistory() {
        history = history.clearing()
        history.save(defaults: defaults)
    }

    // MARK: - Validity helpers (forwarders)

    // The implementations live in `PlateDates`, which is Foundation-only and
    // shared with the widget extension; these forwarders keep the app's many
    // existing `SearchViewModel.*` call sites unchanged.

    static func validity(of dateString: String?, now: Date = .now) -> ValidityStatus {
        PlateDates.validity(of: dateString, now: now)
    }

    static func parse(_ dateString: String) -> Date? {
        PlateDates.parse(dateString)
    }

    /// Formats an API date string into a friendly Hebrew `d בMONTH yyyy` form.
    static func displayDate(_ dateString: String?) -> String? {
        PlateDates.displayDate(dateString)
    }

    /// Formats an ownership `baalut_dt` integer (YYYYMM, e.g. 202106) into a
    /// Hebrew `MONTH yyyy` form (e.g. "יוני 2021"). `nil` if unparseable.
    static func displayMonthYear(_ yyyymm: Int?) -> String? {
        guard let yyyymm else { return nil }
        let year = yyyymm / 100
        let month = yyyymm % 100
        guard (1...12).contains(month), year > 1900 else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        guard let date = Calendar(identifier: .gregorian).date(from: components) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
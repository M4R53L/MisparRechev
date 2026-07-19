import Foundation
import SwiftUI

/// UI state machine for the lookup flow.
enum LookupState: Equatable {
    case empty
    case loading
    case loaded(LookupResult)
    case error(VehicleError)
}

/// Whether a date-based validity (test/license) is active, expiring soon, or
/// expired. Used by the design system to pick a status color.
enum ValidityStatus: Equatable {
    case valid, expiringSoon, expired, unknown
}

@Observable
final class SearchViewModel {
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

    private let service: VehicleService
    private let defaults: UserDefaults
    private var inflight: Task<Void, Never>?

    init(
        service: VehicleService = VehicleService(),
        history: SearchHistoryStore = .load(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.history = history
        self.defaults = defaults
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
                    self.state = .loaded(result)
                    self.history = self.history.recording(
                        plate: plate,
                        manufacturer: result.vehicle.manufacturer,
                        model: result.vehicle.model,
                        year: result.vehicle.year)
                    self.history.save(defaults: self.defaults)
                }
            } catch let error as VehicleError {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.state = .error(error)
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    self.state = .error(.server(String(describing: error)))
                }
            }
        }
    }

    /// Re-run a lookup for a plate tapped in history.
    func search(plate: Int) {
        plateInput = String(plate)
        search()
    }

    /// Clear back to the empty/hero state.
    func reset() {
        inflight?.cancel()
        plateInput = ""
        state = .empty
    }

    func removeHistory(plate: Int) {
        history = history.removing(plate: plate)
        history.save(defaults: defaults)
    }

    func clearHistory() {
        history = history.clearing()
        history.save(defaults: defaults)
    }

    // MARK: - Validity helpers

    /// Computes validity status for a date string coming from the API.
    /// Accepts several formats (`yyyy-MM-dd`, `dd/MM/yyyy`, ISO with time).
    ///
    /// `now` is injectable for deterministic tests; views call the no-arg form.
    static func validity(of dateString: String?, now: Date = .now) -> ValidityStatus {
        guard let dateString, let date = parse(dateString) else { return .unknown }
        let calendar = Calendar.current
        if date < calendar.startOfDay(for: now) { return .expired }
        if let soon = calendar.date(byAdding: .month, value: 2, to: now), date <= soon {
            return .expiringSoon
        }
        return .valid
    }

    private static let formatters: [DateFormatter] = {
        // Order matters: more specific formats first so "2017-03-16" is not
        // half-parsed by the loose "yyyy-M" format (last). Strict matching.
        let formats = ["yyyy-MM-dd'T'HH:mm:ss",
                       "yyyy-MM-dd HH:mm:ss",
                       "yyyy-MM-dd",
                       "dd/MM/yyyy",
                       "dd-MM-yyyy",
                       "yyyy-M"]
        return formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "Asia/Jerusalem")
            f.isLenient = false
            f.dateFormat = fmt
            return f
        }
    }()

    static func parse(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// Formats an API date string into a friendly Hebrew `d בMONTH yyyy` form.
    static func displayDate(_ dateString: String?) -> String? {
        guard let dateString, let date = parse(dateString) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "d בMMMM yyyy"
        return formatter.string(from: date)
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
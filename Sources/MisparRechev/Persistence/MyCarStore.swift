import Foundation

/// The single pinned "הרכב שלי", persisted whole as JSON in App-Group
/// UserDefaults so the widget extension can read it; falls back to `.standard`
/// when the group container is unavailable (e.g. entitlement dropped on a
/// free personal team — everything but widget data-sharing keeps working).
///
/// IMPORTANT: this file is compiled into the widget extension target too, so
/// it must stay Foundation-only and must not reference the app's model layer
/// (`LookupResult`, `Vehicle`, …) — hence the primitives-only API.
struct MyCarStore: Codable, Equatable {
    static let appGroupID = "group.il.misparrechev.shared"
    private static let key = "il.misparrechev.myCar"

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    struct PinnedCar: Codable, Equatable {
        let plate: Int
        /// Display title like "C300E • 2020" (falls back to the plate string).
        let title: String
        /// Latest known raw test-expiry string (e.g. "2027-07-06").
        var tokefDt: String?
        /// Open-recall IDs as of the last refresh (already notified).
        var knownRecallIDs: [Int]
        var lastRefreshed: Date?
        let pinnedAt: Date
    }

    private(set) var car: PinnedCar?

    // MARK: - Persistence

    static func load(defaults: UserDefaults = sharedDefaults) -> MyCarStore {
        guard let data = defaults.data(forKey: key),
              let store = try? JSONDecoder().decode(MyCarStore.self, from: data) else {
            return MyCarStore()
        }
        return store
    }

    func save(defaults: UserDefaults = sharedDefaults) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.key)
    }

    // MARK: - Mutations (value-returning, caller saves)

    func pinning(plate: Int, title: String, tokefDt: String?, recallIDs: [Int],
                 at date: Date = .now) -> MyCarStore {
        var copy = self
        copy.car = PinnedCar(plate: plate, title: title, tokefDt: tokefDt,
                             knownRecallIDs: recallIDs.sorted(),
                             lastRefreshed: date, pinnedAt: date)
        return copy
    }

    func unpinning() -> MyCarStore {
        var copy = self
        copy.car = nil
        return copy
    }

    /// Refresh-time update: replaces the status fields, keeps identity fields.
    /// No-op when nothing is pinned.
    func updating(tokefDt: String?, knownRecallIDs: [Int], refreshedAt: Date) -> MyCarStore {
        guard var car else { return self }
        car.tokefDt = tokefDt
        car.knownRecallIDs = knownRecallIDs.sorted()
        car.lastRefreshed = refreshedAt
        var copy = self
        copy.car = car
        return copy
    }
}

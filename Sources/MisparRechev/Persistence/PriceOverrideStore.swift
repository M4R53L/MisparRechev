import Foundation

/// Per-plate manual current-value overrides, persisted in `UserDefaults`.
///
/// The in-app value is only a crude depreciation estimate (`PriceEstimator`),
/// so the user can look the plate up in a professional guide (לוי יצחק) and
/// type the real number in; the override then drives the price card, the share
/// text and the PDF report.
///
/// Value-type API mirroring `SearchHistoryStore`: mutators return a new value
/// and the caller saves explicitly.
struct PriceOverrideStore: Codable, Equatable {
    private static let key = "il.misparrechev.priceOverrides"
    /// Keeps the dictionary bounded; oldest edits are dropped first.
    static let maxEntries = 200

    struct Override: Codable, Equatable {
        let shekels: Int
        let savedAt: Date
    }

    private(set) var overrides: [Int: Override] = [:]

    /// Load from `UserDefaults` (empty if none or unreadable).
    static func load(defaults: UserDefaults = .standard) -> PriceOverrideStore {
        guard let data = defaults.data(forKey: Self.key),
              let store = try? JSONDecoder().decode(PriceOverrideStore.self, from: data)
        else { return PriceOverrideStore() }
        return store
    }

    /// Persist to `UserDefaults` (silently ignores encode failure).
    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private enum CodingKeys: String, CodingKey { case overrides }

    /// The manually entered value for a plate, if any.
    func value(for plate: Int) -> Int? {
        overrides[plate]?.shekels
    }

    /// Store (or replace) a plate's manual value. Non-positive amounts clear
    /// the override instead, so "0" in the edit field means "back to the
    /// automatic estimate".
    func setting(_ shekels: Int?, for plate: Int, at date: Date = .now) -> PriceOverrideStore {
        guard let shekels, shekels > 0 else { return removing(plate: plate) }
        var next = self
        next.overrides[plate] = Override(shekels: shekels, savedAt: date)
        if next.overrides.count > Self.maxEntries {
            let keep = next.overrides
                .sorted { $0.value.savedAt > $1.value.savedAt }
                .prefix(Self.maxEntries)
            next.overrides = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        return next
    }

    /// Drop a plate's manual value (falls back to the automatic estimate).
    func removing(plate: Int) -> PriceOverrideStore {
        var next = self
        next.overrides[plate] = nil
        return next
    }
}

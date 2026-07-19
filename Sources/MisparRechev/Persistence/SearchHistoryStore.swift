import Foundation

/// Persists recently-looked-up plates in `UserDefaults`, newest first, capped
/// to a small number so the list stays useful.
struct SearchHistoryStore: Codable, Equatable {
    private static let key = "il.misparrechev.searchHistory"
    /// Caps stored history so it stays useful but doesn't grow unbounded in
    /// `UserDefaults`. The list renders in a `ScrollView`, so no pagination is
    /// needed at this scale.
    static let maxEntries = 100

    struct Entry: Codable, Identifiable, Equatable, Hashable {
        let plate: Int
        let timestamp: Date
        /// Vehicle display info captured on a successful lookup. Optional so
        /// entries persisted by earlier app versions decode with `nil`s.
        let manufacturer: String?
        let model: String?
        let year: String?
        var id: Int { plate }

        /// Display title like "MX 5 • 2008"; `nil` when nothing beyond the
        /// plate number is known (legacy entries).
        var title: String? {
            let parts = [model ?? manufacturer, year].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        }
    }

    private(set) var entries: [Entry] = []

    /// Load from `UserDefaults` (empty if none or unreadable).
    static func load(defaults: UserDefaults = .standard) -> SearchHistoryStore {
        guard let data = defaults.data(forKey: Self.key),
              let store = try? JSONDecoder().decode(SearchHistoryStore.self, from: data)
        else { return SearchHistoryStore() }
        return store
    }

    /// Persist to `UserDefaults` (silently ignores encode failure).
    func save(defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private enum CodingKeys: String, CodingKey { case entries }

    /// Record a lookup, de-duplicating by plate and keeping the most recent
    /// timestamp (and vehicle info, when provided). Returns a new store
    /// (value type). Re-recording a plate replaces its entry, so legacy
    /// number-only entries upgrade in place.
    func recording(plate: Int, manufacturer: String? = nil, model: String? = nil,
                   year: String? = nil, at date: Date = .now) -> SearchHistoryStore {
        let filtered = entries.filter { $0.plate != plate }
        var updated = filtered
        updated.insert(Entry(plate: plate, timestamp: date, manufacturer: manufacturer,
                             model: model, year: year), at: 0)
        if updated.count > Self.maxEntries {
            updated = Array(updated.prefix(Self.maxEntries))
        }
        var next = self
        next.entries = updated
        return next
    }

    /// Remove a single plate from history.
    func removing(plate: Int) -> SearchHistoryStore {
        var next = self
        next.entries = entries.filter { $0.plate != plate }
        return next
    }

    /// Clear all history.
    func clearing() -> SearchHistoryStore {
        var next = self
        next.entries = []
        return next
    }
}
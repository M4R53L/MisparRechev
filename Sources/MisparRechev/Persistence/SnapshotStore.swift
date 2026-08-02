import Foundation

/// Full `LookupResult` snapshots persisted as one JSON file in Application
/// Support, keyed by plate and capped by recency — the offline layer behind
/// instant history taps and the network-failure fallback.
///
/// Value-type API mirroring `SearchHistoryStore`: mutators return a new value
/// and the caller saves explicitly. Load/save are best-effort — any failure
/// degrades to an empty store, never to a crash.
struct SnapshotStore: Codable, Equatable {
    struct Snapshot: Codable, Equatable {
        let result: LookupResult
        let savedAt: Date
    }

    static let maxSnapshots = 40

    private(set) var snapshots: [Int: Snapshot] = [:]

    /// …/Application Support/snapshots.json (directory created on demand).
    static let defaultFileURL: URL = {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true))
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("snapshots.json")
    }()

    static func load(url: URL = defaultFileURL) -> SnapshotStore {
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(SnapshotStore.self, from: data) else {
            return SnapshotStore()
        }
        return store
    }

    func save(url: URL = SnapshotStore.defaultFileURL) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func snapshot(for plate: Int) -> Snapshot? { snapshots[plate] }

    /// Inserts/replaces the plate's snapshot, then evicts the oldest entries
    /// (by `savedAt`) beyond `maxSnapshots`.
    func saving(_ result: LookupResult, for plate: Int, at date: Date = .now) -> SnapshotStore {
        var copy = self
        copy.snapshots[plate] = Snapshot(result: result, savedAt: date)
        while copy.snapshots.count > Self.maxSnapshots,
              let oldest = copy.snapshots.min(by: { $0.value.savedAt < $1.value.savedAt }) {
            copy.snapshots.removeValue(forKey: oldest.key)
        }
        return copy
    }

    func removing(plate: Int) -> SnapshotStore {
        var copy = self
        copy.snapshots.removeValue(forKey: plate)
        return copy
    }
}

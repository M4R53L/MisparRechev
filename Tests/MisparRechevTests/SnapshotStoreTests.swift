import XCTest
@testable import MisparRechev

/// File-backed offline-snapshot store: Codable round-trip of full lookup
/// results, recency-capped eviction, and failure-tolerant load.
final class SnapshotStoreTests: XCTestCase {

    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("snapshots-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "test", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "missing fixture \(name).json"])
        }
        return try Data(contentsOf: url)
    }

    /// A fixture-built result exercising every Codable member of LookupResult.
    private func fullResult() throws -> LookupResult {
        let vehicle = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: fixture("primary_5970065"))
                .result?.records?.first)
        let spec = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<VehicleSpec>.self, from: fixture("specs_5970065"))
                .result?.records?.first)
        let mileage = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<VehicleHistory>.self, from: fixture("history_5970065"))
                .result?.records?.first)
        let ownership = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<OwnershipRecord>.self, from: fixture("ownership_3256880"))
                .result?.records)
        let recalls = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<RecallRecord>.self, from: fixture("recall_5569379"))
                .result?.records)
        let prices = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<NewCarPrice>.self, from: fixture("price_77720101"))
                .result?.records)
        return LookupResult(vehicle: vehicle, spec: spec, mileage: mileage,
                            ownership: ownership, recalls: recalls,
                            prices: prices)
    }

    func testRoundTripEncodeDecodeFullLookupResult() throws {
        let result = try fullResult()
        var store = SnapshotStore()
        store = store.saving(result, for: result.vehicle.mispar_rechev)
        store.save(url: fileURL)

        let reloaded = SnapshotStore.load(url: fileURL)
        XCTAssertEqual(reloaded, store, "Equatable proves the encode/decode symmetry")
        let snap = try XCTUnwrap(reloaded.snapshot(for: result.vehicle.mispar_rechev))
        XCTAssertEqual(snap.result, result)
        XCTAssertEqual(snap.result.spec?.koah_sus, 160)
        XCTAssertEqual(snap.result.prices.count, 1)
        XCTAssertEqual(snap.result.prices.first?.mehir, 375900)
    }

    func testSavingReplacesSamePlateAndCapsByRecency() throws {
        let result = try fullResult()
        var store = SnapshotStore()
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        // 41 distinct plates with staggered savedAt → oldest is evicted.
        for i in 0...SnapshotStore.maxSnapshots {
            store = store.saving(result, for: 1_000_000 + i,
                                 at: base.addingTimeInterval(Double(i)))
        }
        XCTAssertEqual(store.snapshots.count, SnapshotStore.maxSnapshots)
        XCTAssertNil(store.snapshot(for: 1_000_000), "oldest evicted")
        XCTAssertNotNil(store.snapshot(for: 1_000_000 + SnapshotStore.maxSnapshots))

        // Re-saving an existing plate replaces (no growth) and bumps savedAt.
        let countBefore = store.snapshots.count
        store = store.saving(result, for: 1_000_001, at: base.addingTimeInterval(9_999))
        XCTAssertEqual(store.snapshots.count, countBefore)
        XCTAssertEqual(store.snapshot(for: 1_000_001)?.savedAt,
                       base.addingTimeInterval(9_999))
    }

    func testRemovingAndLookup() throws {
        let result = try fullResult()
        var store = SnapshotStore().saving(result, for: 5970065)
        XCTAssertNotNil(store.snapshot(for: 5970065))
        XCTAssertNil(store.snapshot(for: 1234567))
        store = store.removing(plate: 5970065)
        XCTAssertNil(store.snapshot(for: 5970065))
    }

    func testLoadReturnsEmptyOnMissingOrCorruptFile() throws {
        XCTAssertEqual(SnapshotStore.load(url: fileURL), SnapshotStore())
        try Data("not json".utf8).write(to: fileURL)
        XCTAssertEqual(SnapshotStore.load(url: fileURL), SnapshotStore())
    }
}

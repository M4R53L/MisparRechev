import XCTest
@testable import MisparRechev

/// Persistence tests for `SearchHistoryStore`, focused on the vehicle-info
/// fields added to `Entry` and backward compatibility with entries persisted
/// by app versions that stored only plate + timestamp.
final class SearchHistoryStoreTests: XCTestCase {

    func testHistoryEntryRoundTripsVehicleInfo() throws {
        var store = SearchHistoryStore()
        store = store.recording(plate: 5970065, manufacturer: "מזדה יפן",
                                model: "MX 5", year: "2008")

        let data = try JSONEncoder().encode(store)
        let decoded = try JSONDecoder().decode(SearchHistoryStore.self, from: data)

        let entry = try XCTUnwrap(decoded.entries.first)
        XCTAssertEqual(entry.plate, 5970065)
        XCTAssertEqual(entry.manufacturer, "מזדה יפן")
        XCTAssertEqual(entry.model, "MX 5")
        XCTAssertEqual(entry.year, "2008")
        XCTAssertEqual(entry.title, "MX 5 • 2008")
    }

    /// JSON persisted by versions whose `Entry` had only `plate` + `timestamp`
    /// (Date encodes as secondsSinceReferenceDate) must still decode.
    func testHistoryDecodesLegacyEntriesWithoutVehicleInfo() throws {
        let legacy = #"{"entries":[{"plate":5970065,"timestamp":712345678.0}]}"#
            .data(using: .utf8)!
        let store = try JSONDecoder().decode(SearchHistoryStore.self, from: legacy)

        let entry = try XCTUnwrap(store.entries.first)
        XCTAssertEqual(entry.plate, 5970065)
        XCTAssertNil(entry.manufacturer)
        XCTAssertNil(entry.model)
        XCTAssertNil(entry.year)
        XCTAssertNil(entry.title)
    }

    /// Re-recording a plate replaces its entry, upgrading legacy number-only
    /// entries with vehicle info in place.
    func testRecordingUpgradesLegacyEntry() {
        var store = SearchHistoryStore()
        store = store.recording(plate: 5970065)
        XCTAssertNil(store.entries.first?.title)

        store = store.recording(plate: 5970065, manufacturer: "מזדה יפן",
                                model: "MX 5", year: "2008")
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.title, "MX 5 • 2008")
    }

    /// A vehicle with no model falls back to the manufacturer; year-only and
    /// name-only entries still produce a title.
    func testTitleFallsBackToManufacturer() {
        let store = SearchHistoryStore()
            .recording(plate: 17070204, manufacturer: "הייגר סין", year: "2025")
        XCTAssertEqual(store.entries.first?.title, "הייגר סין • 2025")
    }
}

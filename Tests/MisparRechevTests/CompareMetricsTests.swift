import XCTest
@testable import MisparRechev

/// Pure row-building logic behind the side-by-side comparison table.
final class CompareMetricsTests: XCTestCase {

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "test", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "missing fixture \(name).json"])
        }
        return try Data(contentsOf: url)
    }

    private func record<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<T>.self, from: fixture(name))
                .result?.records?.first)
    }

    private func records<T: Decodable>(_ type: T.Type, _ name: String) throws -> [T] {
        try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<T>.self, from: fixture(name))
                .result?.records)
    }

    /// MX-5 2008: history + ownership + one recall, no price record.
    private func mx5() throws -> LookupResult {
        LookupResult(
            vehicle: try record(Vehicle.self, "primary_5970065"),
            spec: try record(VehicleSpec.self, "specs_5970065"),
            mileage: try record(VehicleHistory.self, "history_5970065"),
            ownership: try records(OwnershipRecord.self, "ownership_3256880"),
            recalls: [try record(RecallRecord.self, "recall_5569379")],
            prices: []
        )
    }

    /// C300E 2020 hybrid: spec + its exact-year price record, no history.
    private func c300e() throws -> LookupResult {
        LookupResult(
            vehicle: try record(Vehicle.self, "primary_77720101"),
            spec: try record(VehicleSpec.self, "specs_77720101"),
            mileage: nil,
            ownership: [],
            recalls: [],
            prices: try records(NewCarPrice.self, "price_77720101")
        )
    }

    private func value(_ rows: [CompareMetrics.Row], _ label: String) throws -> CompareMetrics.Row {
        try XCTUnwrap(rows.first { $0.label == label }, "missing row \(label)")
    }

    func testRowsFromTwoFixtureResults() throws {
        let rows = CompareMetrics.rows(a: try mx5(), b: try c300e())

        XCTAssertEqual(try value(rows, "שנת ייצור").a, "2008")
        XCTAssertEqual(try value(rows, "שנת ייצור").b, "2020")
        XCTAssertEqual(try value(rows, "הספק (כ״ס)").a, "160")
        XCTAssertEqual(try value(rows, "הספק (כ״ס)").b, "211")
        XCTAssertEqual(try value(rows, "תיבת הילוכים").a, "ידנית")
        XCTAssertEqual(try value(rows, "תיבת הילוכים").b, "אוטומטית")
        XCTAssertEqual(try value(rows, "פליטת CO2").a, "181")
        XCTAssertEqual(try value(rows, "פליטת CO2").b, "36 (WLTP)")
        XCTAssertEqual(try value(rows, "קילומטראז׳").a, "159816 ק\"מ")
        XCTAssertNil(try value(rows, "קילומטראז׳").b)
        XCTAssertEqual(try value(rows, "רשומות בעלות").a, "3")
        XCTAssertNil(try value(rows, "רשומות בעלות").b, "no ownership records → nil, not 0")
        XCTAssertEqual(try value(rows, "ריקולים פתוחים").a, "1")
        XCTAssertEqual(try value(rows, "ריקולים פתוחים").b, "0")
        XCTAssertEqual(try value(rows, "רמת אבזור בטיחותי").b, "2 / 8")
        XCTAssertEqual(try value(rows, "קבוצת זיהום").a, "15 / 15")
        XCTAssertEqual(try value(rows, "קבוצת זיהום").b, "2 / 15")
        XCTAssertEqual(try value(rows, "כריות אוויר").a, "4")
        XCTAssertEqual(try value(rows, "כריות אוויר").b, "7")
    }

    func testPriceRowsUseFormattedShekels() throws {
        let rows = CompareMetrics.rows(a: try mx5(), b: try c300e())

        // MX-5 has no price record → both price rows nil on side A.
        XCTAssertNil(try value(rows, "מחיר מחירון כחדש").a)
        XCTAssertNil(try value(rows, "שווי מוערך").a)

        XCTAssertEqual(try value(rows, "מחיר מחירון כחדש").b,
                       PriceEstimator.formatted(375900))
        XCTAssertNotNil(try value(rows, "שווי מוערך").b,
                        "single price + year → estimate present")
    }

    func testNilSidesYieldNilValues() throws {
        let rows = CompareMetrics.rows(a: try mx5(), b: nil)
        XCTAssertFalse(rows.isEmpty)
        XCTAssertTrue(rows.allSatisfy { $0.b == nil }, "missing side → all-nil column")
        XCTAssertNotNil(try value(rows, "שנת ייצור").a)

        let empty = CompareMetrics.rows(a: nil, b: nil)
        XCTAssertTrue(empty.allSatisfy { $0.a == nil && $0.b == nil })
    }
}

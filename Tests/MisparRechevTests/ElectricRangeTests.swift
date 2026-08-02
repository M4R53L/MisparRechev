import XCTest
@testable import MisparRechev

/// Unit tests for the EEA-backed WLTP electric-range logic. All offline
/// except the last test, which hits the live DiscoData endpoint and skips
/// when the network is unavailable.
final class ElectricRangeTests: XCTestCase {

    // MARK: - Helpers

    private func vehicle(_ json: String) throws -> Vehicle {
        try JSONDecoder().decode(Vehicle.self, from: Data(json.utf8))
    }

    private func spec(_ json: String) throws -> VehicleSpec {
        try JSONDecoder().decode(VehicleSpec.self, from: Data(json.utf8))
    }

    private func row(ep: Double?, zr: Double, n: Int) -> ElectricRange.Row {
        .init(ep: ep, zr: zr, n: n)
    }

    // MARK: - Kind detection

    func testKindDetection() throws {
        let petrol = try vehicle(#"{"mispar_rechev":1,"sug_delek_nm":"בנזין"}"#)
        let ev = try vehicle(#"{"mispar_rechev":1,"sug_delek_nm":"חשמל"}"#)

        XCTAssertEqual(
            ElectricRange.kind(vehicle: petrol,
                               spec: try spec(#"{"technologiat_hanaa_nm":"PLUG IN"}"#)),
            .plugInHybrid)
        XCTAssertEqual(
            ElectricRange.kind(vehicle: petrol,
                               spec: try spec(#"{"technologiat_hanaa_nm":"רכב חשמלי"}"#)),
            .battery)
        // Spec-less EV (fallback datasets): classified by fuel type alone.
        XCTAssertEqual(ElectricRange.kind(vehicle: ev, spec: nil), .battery)
        // Regular hybrids and combustion cars have no plug-in range.
        XCTAssertNil(ElectricRange.kind(vehicle: petrol,
                                        spec: try spec(#"{"technologiat_hanaa_nm":"היברידי"}"#)))
        XCTAssertNil(ElectricRange.kind(vehicle: petrol,
                                        spec: try spec(#"{"technologiat_hanaa_nm":"הנעה רגילה"}"#)))
        XCTAssertNil(ElectricRange.kind(vehicle: petrol, spec: nil))
    }

    // MARK: - Query-name sanitization

    func testQueryNameSanitization() {
        XCTAssertEqual(ElectricRange.queryName(from: " model 3 "), "MODEL 3")
        // Quotes and LIKE wildcards are stripped, never escaped.
        XCTAssertEqual(ElectricRange.queryName(from: "ATTO'3%_"), "ATTO3")
        XCTAssertEqual(ElectricRange.queryName(from: "IONIQ  5"), "IONIQ 5")
        XCTAssertNil(ElectricRange.queryName(from: nil))
        XCTAssertNil(ElectricRange.queryName(from: "יונדאי"), "Hebrew-only name has nothing to match")
        XCTAssertNil(ElectricRange.queryName(from: "X"), "too short to match safely")
    }

    // MARK: - Table routing

    func testTableRouting() {
        XCTAssertNil(ElectricRange.tableName(forYear: 2019), "pre-WLTP era has no Zr data")
        XCTAssertEqual(ElectricRange.tableName(forYear: 2021),
                       "[CO2Emission].[latest].[co2cars]")
        XCTAssertEqual(ElectricRange.tableName(forYear: 2022),
                       "[CO2Emission].[latest].[co2cars]")
        XCTAssertEqual(ElectricRange.tableName(forYear: 2023),
                       "[CO2Emission].[latest].[co2cars_2023Fv28]")
        XCTAssertEqual(ElectricRange.tableName(forYear: 2024),
                       "[CO2Emission].[latest].[co2cars_2024Pv29]")
        // Years beyond the newest published table clamp to it.
        XCTAssertEqual(ElectricRange.tableName(forYear: 2027),
                       ElectricRange.tableName(forYear: 2025))
        XCTAssertTrue(ElectricRange.needsYearFilter(2022))
        XCTAssertFalse(ElectricRange.needsYearFilter(2023))
    }

    func testQueryURLComposition() throws {
        let url = ElectricRange.queryURL(table: "[CO2Emission].[latest].[co2cars]",
                                         name: "MODEL 3", kind: .battery, year: 2021)
        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let sql = try XCTUnwrap(items.first { $0.name == "query" }?.value)
        XCTAssertTrue(sql.contains("UPPER(Cn) LIKE '%MODEL 3%'"))
        XCTAssertTrue(sql.contains("UPPER(Ft) = 'ELECTRIC'"))
        XCTAssertTrue(sql.contains("[Year] = 2021"))
        XCTAssertTrue(sql.contains("Zr IS NOT NULL"))

        let phevURL = ElectricRange.queryURL(table: "[CO2Emission].[latest].[co2cars_2024Pv29]",
                                             name: "EHS", kind: .plugInHybrid, year: nil)
        let phevItems = try XCTUnwrap(URLComponents(url: phevURL, resolvingAgainstBaseURL: false)?.queryItems)
        let phevSQL = try XCTUnwrap(phevItems.first { $0.name == "query" }?.value)
        XCTAssertTrue(phevSQL.contains("UPPER(Fm) = 'P'"))
        XCTAssertFalse(phevSQL.contains("[Year]"))
    }

    // MARK: - Value selection

    /// Real aggregation shape for Model 3 / 2021: the horsepower (498 hp ≈
    /// 366 kW) must select the Long Range trim's 614 km, not the globally
    /// most-registered Standard Range value.
    func testPickUsesHorsepowerToSelectTrim() {
        let rows = [
            row(ep: 100, zr: 448, n: 20850),
            row(ep: 239, zr: 448, n: 9446),
            row(ep: 366, zr: 614, n: 6000),
            row(ep: 366, zr: 580, n: 4984),
            row(ep: 377, zr: 567, n: 2690),
            row(ep: 366, zr: 640, n: 456)
        ]
        XCTAssertEqual(ElectricRange.pick(rows: rows, horsepower: 498, kind: .battery), 614)
        // Without horsepower, the most-registered value wins.
        XCTAssertEqual(ElectricRange.pick(rows: rows, horsepower: nil, kind: .battery), 448)
        // Horsepower matching nothing falls back to the global mode.
        XCTAssertEqual(ElectricRange.pick(rows: rows, horsepower: 2000, kind: .battery), 448)
    }

    func testPickAggregatesSameRangeAcrossPowerGroups() {
        let rows = [
            row(ep: 150, zr: 420, n: 300),
            row(ep: 160, zr: 420, n: 300),
            row(ep: 150, zr: 565, n: 400)
        ]
        // 420 km carries 600 registrations combined vs 565's 400.
        XCTAssertEqual(ElectricRange.pick(rows: rows, horsepower: nil, kind: .battery), 420)
    }

    func testPickDropsImplausibleValues() {
        let bev = [
            row(ep: 150, zr: 40, n: 9000), // typo'd outlier
            row(ep: 150, zr: 420, n: 100)
        ]
        XCTAssertEqual(ElectricRange.pick(rows: bev, horsepower: nil, kind: .battery), 420)
        XCTAssertNil(ElectricRange.pick(rows: [row(ep: 150, zr: 40, n: 9000)],
                                        horsepower: nil, kind: .battery))
        XCTAssertNil(ElectricRange.pick(rows: [], horsepower: nil, kind: .battery))
    }

    /// PHEV: EU engine power never matches the Israeli system horsepower, so
    /// horsepower is ignored and the model-wide mode wins (real MG EHS shape).
    func testPickPHEVIgnoresHorsepower() {
        let rows = [
            row(ep: 119, zr: 54, n: 1961),
            row(ep: 119, zr: 52, n: 923),
            row(ep: 119, zr: 53, n: 22),
            row(ep: 105, zr: 127, n: 18)
        ]
        XCTAssertEqual(ElectricRange.pick(rows: rows, horsepower: 306, kind: .plugInHybrid), 54)
    }

    // MARK: - Live (auto-skips offline)

    /// End-to-end against the live EEA DiscoData endpoint: URL building,
    /// response decoding, and trim selection for a 2021 Model 3 Long Range.
    func testLiveDiscoDataModel3() async throws {
        let url = ElectricRange.queryURL(table: "[CO2Emission].[latest].[co2cars]",
                                         name: "MODEL 3", kind: .battery, year: 2021)
        let data: Data
        do {
            (data, _) = try await URLSession.shared.data(from: url)
        } catch {
            throw XCTSkip("EEA DiscoData unreachable: \(error)")
        }
        let rows = try JSONDecoder().decode(ElectricRange.Response.self, from: data).results ?? []
        XCTAssertFalse(rows.isEmpty, "expected aggregated rows for MODEL 3 / 2021")
        let km = try XCTUnwrap(ElectricRange.pick(rows: rows, horsepower: 498, kind: .battery))
        XCTAssertTrue((450...750).contains(km), "implausible WLTP range \(km) km")
        print("✅ LIVE EEA: Model 3 LR 2021 → \(km) km WLTP")
    }
}

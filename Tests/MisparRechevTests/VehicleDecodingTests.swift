import XCTest
@testable import MisparRechev

/// Decoding + service tests for the data.gov.il response shapes.
///
/// Fixtures live in `Fixtures/` and are bundled as resources of the test target.
final class VehicleDecodingTests: XCTestCase {

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "test", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "missing fixture \(name).json"])
        }
        return try Data(contentsOf: url)
    }

    // MARK: - Primary vehicle decoding

    func testDecodesPrimaryVehicleFromFixture() throws {
        let data = try fixture("primary_5970065")
        let response = try JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: data)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.result?.total, 1)

        let vehicle = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(vehicle.mispar_rechev, 5970065)
        XCTAssertEqual(vehicle.tozeret_nm, "מזדה יפן")
        XCTAssertEqual(vehicle.kinuy_mishari, "MX 5")
        XCTAssertEqual(vehicle.shnat_yitzur, 2008)
        XCTAssertEqual(vehicle.tzeva_rechev, "אפור")
        XCTAssertEqual(vehicle.sug_delek_nm, "בנזין")
        XCTAssertEqual(vehicle.kvutzat_zihum, 15)
        XCTAssertEqual(vehicle.tokef_dt, "2027-05-24")
        XCTAssertEqual(vehicle.mivchan_acharon_dt, "2026-05-24")
        XCTAssertEqual(vehicle.baalut, "פרטי")
        XCTAssertEqual(vehicle.misgeret, "JMZNC18F6-80153489")
        // Engine cc / weights are not part of this resource → nil (hidden in UI).
        XCTAssertNil(vehicle.nefach_manoa)
        XCTAssertNil(vehicle.mishkal_kolel)

        // Computed helpers
        XCTAssertEqual(vehicle.manufacturer, "מזדה יפן")
        XCTAssertEqual(vehicle.model, "MX 5")
        XCTAssertEqual(vehicle.year, "2008")
        XCTAssertEqual(vehicle.displayName, "MX 5")
        XCTAssertEqual(vehicle.ownershipType, "פרטי")
        XCTAssertEqual(vehicle.chassis, "JMZNC18F6-80153489")
        // An active vehicle has no cancellation date.
        XCTAssertNil(vehicle.bitul_dt)
        XCTAssertFalse(vehicle.isDeregistered)
    }

    // MARK: - Deregistered vehicle (ביטול סופי)

    /// The "ירדו מהכביש" resources return near-full vehicle records plus
    /// `bitul_dt` — the only field that marks a record as deregistered.
    func testDecodesDeregisteredVehicleFromFixture() throws {
        let data = try fixture("deregistered_1442562")
        let response = try JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: data)

        let vehicle = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(vehicle.mispar_rechev, 1442562)
        XCTAssertEqual(vehicle.bitul_dt, "2026-07-30 00:00:00")
        XCTAssertTrue(vehicle.isDeregistered)
        // The cancellation date parses with the app's existing formats (#2).
        XCTAssertNotNil(SearchViewModel.parse(try XCTUnwrap(vehicle.bitul_dt)))
        XCTAssertEqual(vehicle.tozeret_nm, "טויוטה צרפת")
        XCTAssertEqual(vehicle.shnat_yitzur, 2007)
        XCTAssertEqual(vehicle.vehicleType, "פרטי נוסעים 5 דלתות")
        XCTAssertEqual(vehicle.chassis, "VNKKL98377A100109")
        // No sug_degem in these resources → the price/spec joins skip.
        XCTAssertNil(vehicle.sug_degem)
    }

    func testVehicleWithMissingFieldsStillDecodes() throws {
        // Build a minimal record — every non-plate field optional.
        let json = """
        { "success": true, "result": { "records": [ { "mispar_rechev": 1234567 } ] } }
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: json)
        let vehicle = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(vehicle.mispar_rechev, 1234567)
        XCTAssertNil(vehicle.tozeret_nm)
        XCTAssertNil(vehicle.shnat_yitzur)
        XCTAssertEqual(vehicle.year, nil)
        // displayName falls back to the plate.
        XCTAssertEqual(vehicle.displayName, "מספר רכב 1234567")
    }

    // MARK: - History decoding (0/1 integer flags)

    func testDecodesHistoryWithIntegerFlags() throws {
        let data = try fixture("history_5970065")
        let response = try JSONDecoder().decode(DataGovResponse<VehicleHistory>.self, from: data)

        let history = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(history.mispar_rechev, 3256880)
        XCTAssertEqual(history.mispar_manoa, "CZE 289985")
        XCTAssertEqual(history.kilometer_test_aharon, 159816)
        XCTAssertEqual(history.mileageKm, "159816 ק\"מ")
        XCTAssertEqual(history.engineNumber, "CZE 289985")
        // mkoriut_nm is empty → ownershipSource is nil (hidden in UI).
        XCTAssertNil(history.ownershipSource)

        // 0/1 integer flags coerce to booleans: structural + tire were set.
        XCTAssertTrue(history.structuralChange)
        XCTAssertFalse(history.lpgInstalled)
        XCTAssertFalse(history.colorChange)
        XCTAssertTrue(history.tireChange)
        XCTAssertEqual(history.changeLabels, ["שינוי מבנה", "שינוי צמיג"])
    }

    // MARK: - Numeric safety-equipment level (regression for plate 77720101)

    /// `ramat_eivzur_betihuty` is a numeric field (e.g. `2`), not a string.
    /// Decoding must not fail on it (previously typed as `String?`).
    func testDecodesNumericSafetyEquipmentLevel() throws {
        let data = try fixture("primary_77720101")
        let response = try JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: data)
        let vehicle = try XCTUnwrap(response.result?.records?.first)

        XCTAssertEqual(vehicle.mispar_rechev, 77720101)
        XCTAssertEqual(vehicle.tozeret_nm, "מרצדס בנץ ד.אפ")
        XCTAssertEqual(vehicle.kinuy_mishari, "C300E")
        XCTAssertEqual(vehicle.shnat_yitzur, 2020)
        XCTAssertEqual(vehicle.ramat_eivzur_betihuty, 2, "safety level is an integer")
        XCTAssertEqual(vehicle.kvutzat_zihum, 2)
        // Model-identity codes used for the new-car price join.
        XCTAssertEqual(vehicle.tozeret_cd, 1207)
        XCTAssertEqual(vehicle.degem_cd, 2)
        XCTAssertEqual(vehicle.sug_degem, "P")
        XCTAssertEqual(vehicle.sug_delek_nm, "חשמל/בנזין")
        XCTAssertEqual(vehicle.tokef_dt, "2027-07-06")
        XCTAssertEqual(vehicle.baalut, "פרטי")
        XCTAssertEqual(vehicle.tzeva_rechev, "שחור")
    }

    // MARK: - Ownership timeline

    func testDecodesOwnershipTimeline() throws {
        let data = try fixture("ownership_3256880")
        let response = try JSONDecoder().decode(DataGovResponse<OwnershipRecord>.self, from: data)
        let records = try XCTUnwrap(response.result?.records)
        XCTAssertEqual(records.count, 3)
        XCTAssertEqual(records[0].baalut, "פרטי")
        XCTAssertEqual(records[0].baalut_dt, 201703)
        XCTAssertEqual(records[1].baalut, "סוחר")
        XCTAssertEqual(records[1].baalut_dt, 202105)
        XCTAssertEqual(records[2].baalut, "פרטי")
        XCTAssertEqual(records[2].baalut_dt, 202106)
        XCTAssertEqual(records[0].ownerType, "פרטי")
    }

    func testDisplayMonthYearFormatsYYYYMM() {
        XCTAssertEqual(SearchViewModel.displayMonthYear(201703), "מרץ 2017")
        XCTAssertEqual(SearchViewModel.displayMonthYear(202106), "יוני 2021")
        XCTAssertNil(SearchViewModel.displayMonthYear(nil))
        XCTAssertNil(SearchViewModel.displayMonthYear(2021), "month part missing")
    }

    // MARK: - Personal-import vehicle (regression for plate 9441873)

    /// The personal-import resource uses `shilda` (not `misgeret`) for the
    /// chassis and exposes import-specific fields (`sug_yevu`, country, type).
    func testDecodesPersonalImportVehicle() throws {
        let data = try fixture("import_9441873")
        let response = try JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: data)
        let vehicle = try XCTUnwrap(response.result?.records?.first)

        XCTAssertEqual(vehicle.mispar_rechev, 9441873)
        XCTAssertEqual(vehicle.tozeret_nm, "מרצדס בנץ גרמנ")
        XCTAssertEqual(vehicle.shnat_yitzur, 2011)
        XCTAssertEqual(vehicle.sug_delek_nm, "בנזין")
        XCTAssertEqual(vehicle.nefach_manoa, 3498)
        // Chassis coalesces across field-name variants; here only `shilda` is set.
        XCTAssertEqual(vehicle.chassis, "WDD2183591A000253")
        XCTAssertEqual(vehicle.vehicleType, "פרטי נוסעים")
        XCTAssertEqual(vehicle.countryOfManufacture, "גרמניה")
        XCTAssertEqual(vehicle.importType, "יבוא אישי-משומש")
        XCTAssertEqual(vehicle.engineModel, "M276")
        // Color/pollution/ownership aren't part of this resource → nil (hidden).
        XCTAssertNil(vehicle.tzeva_rechev)
        XCTAssertNil(vehicle.kvutzat_zihum)
        XCTAssertNil(vehicle.ownershipType)
        // mishkal_kolel is 0 (meaning "not provided"); the UI hides zero weights.
        XCTAssertEqual(vehicle.mishkal_kolel, 0)
    }

    // MARK: - Open recalls

    func testDecodesRecallFromFixture() throws {
        let data = try fixture("recall_5569379")
        let response = try JSONDecoder().decode(DataGovResponse<RecallRecord>.self, from: data)

        XCTAssertTrue(response.success)
        let recall = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(recall.MISPAR_RECHEV, 5569379)
        XCTAssertEqual(recall.RECALL_ID, 15947)
        XCTAssertEqual(recall.recallType, "תקלה סידרתית בטיחותית")
        XCTAssertEqual(recall.category, "מנוע ומערכותיו")
        XCTAssertEqual(recall.TAARICH_PTICHA, "2025-03-12")
        // The opening date parses with the app's existing date formats.
        XCTAssertNotNil(SearchViewModel.parse("2025-03-12"))
    }

    /// The recall resource is filter-indexed by UPPERCASE `MISPAR_RECHEV` (a
    /// verified quirk), and a plate can have several recalls → limit must not
    /// be 1.
    func testRecallEndpointUsesUppercaseFilterField() throws {
        let url = DataGovEndpoint.recallSearchURL(plate: 5569379)
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let resource = comps.queryItems?.first { $0.name == "resource_id" }?.value
        let filters = comps.queryItems?.first { $0.name == "filters" }?.value
        let limit = comps.queryItems?.first { $0.name == "limit" }?.value
        XCTAssertEqual(resource, DataGovEndpoint.recallResourceID)
        XCTAssertEqual(filters, #"{"MISPAR_RECHEV":"5569379"}"#)
        XCTAssertNotEqual(limit, "1")
    }

    // MARK: - New-car list price

    func testDecodesNewCarPriceFromFixture() throws {
        let data = try fixture("price_77720101")
        let response = try JSONDecoder().decode(DataGovResponse<NewCarPrice>.self, from: data)

        XCTAssertTrue(response.success)
        let price = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(price.mehir, 375900)
        XCTAssertEqual(price.importer, "כלמוביל מרצדס")
        XCTAssertEqual(price.tozeret_cd, 1207)
        XCTAssertEqual(price.degem_cd, 2)
        XCTAssertEqual(price.shnat_yitzur, 2020)
    }

    func testPriceEndpointFiltersOnFourKeys() throws {
        let url = DataGovEndpoint.priceSearchURL(
            tozeretCd: 1207, degemCd: 2, sugDegem: "P", year: 2020
        )
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let resource = comps.queryItems?.first { $0.name == "resource_id" }?.value
        let filters = comps.queryItems?.first { $0.name == "filters" }?.value
        let limit = comps.queryItems?.first { $0.name == "limit" }?.value
        XCTAssertEqual(resource, DataGovEndpoint.priceResourceID)
        XCTAssertEqual(filters,
                       #"{"tozeret_cd":"1207","degem_cd":"2","sug_degem":"P","shnat_yitzur":"2020"}"#)
        XCTAssertNotEqual(limit, "1")
    }

    // MARK: - Model spec sheet (horsepower & co.)

    func testDecodesVehicleSpecFromFixture() throws {
        let data = try fixture("specs_5970065")
        let response = try JSONDecoder().decode(DataGovResponse<VehicleSpec>.self, from: data)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.result?.total, 1)

        let spec = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(spec.tozeret_cd, 588)
        XCTAssertEqual(spec.degem_cd, 12)
        XCTAssertEqual(spec.koah_sus, 160)
        XCTAssertEqual(spec.nefah_manoa, 1999,
                       "the spec resource spells displacement nefah_manoa (no c)")

        // Display helpers
        XCTAssertEqual(spec.horsepower, 160)
        XCTAssertEqual(spec.displacementCC, 1999)
        XCTAssertEqual(spec.gearbox, "ידנית")
        XCTAssertEqual(spec.driveType, "4X2")
        XCTAssertEqual(spec.bodyType, "קבריולט")
        XCTAssertEqual(spec.seats, 2)
        XCTAssertEqual(spec.doors, 2)
        XCTAssertEqual(spec.airbagCount, 4)
        XCTAssertEqual(spec.hasABS, true)
        XCTAssertEqual(spec.hasStabilityControl, true)
        // "הנעה רגילה" is the unremarkable default → row hidden.
        XCTAssertNil(spec.driveTechnology)
        // Old model: NEDC-era CO2, no WLTP.
        XCTAssertEqual(spec.kamut_CO2, 181)
        XCTAssertNil(spec.CO2_WLTP)
        XCTAssertEqual(spec.co2Display, "181")
        // Towing capacity 0 means "not rated" → hidden.
        XCTAssertNil(spec.towingWithBrakesKg)
        // A 2008 model has no driver-assist systems.
        XCTAssertTrue(spec.safetyFeatures.isEmpty)
    }

    /// The C300E plug-in hybrid exercises the richer spec fields: automatic
    /// gearbox, foreign-language drivetrain value, towing capacity, and a full
    /// set of driver-assist flags. `nikud_betihut` is a float (`2.0`) in this
    /// payload — decoding must succeed because it is deliberately not decoded.
    func testDecodesHybridSpecWithAssistSystems() throws {
        let data = try fixture("specs_77720101")
        let response = try JSONDecoder().decode(DataGovResponse<VehicleSpec>.self, from: data)

        let spec = try XCTUnwrap(response.result?.records?.first)
        XCTAssertEqual(spec.tozeret_cd, 1207)
        XCTAssertEqual(spec.degem_cd, 2)
        XCTAssertEqual(spec.koah_sus, 211)
        XCTAssertEqual(spec.gearbox, "אוטומטית")
        XCTAssertEqual(spec.bodyType, "סדאן")
        XCTAssertEqual(spec.seats, 5)
        XCTAssertEqual(spec.airbagCount, 7)
        // "PLUG IN" is normalized to Hebrew.
        XCTAssertEqual(spec.driveTechnology, "היברידי נטען (Plug-in)")
        XCTAssertEqual(spec.safetyEquipmentLevel, 2)
        // New model: WLTP CO2 only (kamut_CO2 is null in this record).
        XCTAssertNil(spec.kamut_CO2)
        XCTAssertEqual(spec.CO2_WLTP, 36)
        XCTAssertEqual(spec.co2Display, "36 (WLTP)")
        XCTAssertEqual(spec.towingWithBrakesKg, 1800)
        XCTAssertEqual(spec.towingWithoutBrakesKg, 750)
        XCTAssertTrue(spec.safetyFeatures.contains("בקרת סטייה מנתיב"))
        XCTAssertTrue(spec.safetyFeatures.contains("בקרת שיוט אדפטיבית"))
        XCTAssertTrue(spec.safetyFeatures.contains("מצלמת רוורס"))
        XCTAssertFalse(spec.safetyFeatures.contains("זיהוי תמרורי תנועה"),
                       "this model's flag is 0")
    }

    func testSpecEndpointFiltersOnFourKeys() throws {
        let url = DataGovEndpoint.specSearchURL(
            tozeretCd: 588, degemCd: 12, sugDegem: "P", year: 2008
        )
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let resource = comps.queryItems?.first { $0.name == "resource_id" }?.value
        let filters = comps.queryItems?.first { $0.name == "filters" }?.value
        let limit = comps.queryItems?.first { $0.name == "limit" }?.value
        XCTAssertEqual(resource, DataGovEndpoint.specResourceID)
        XCTAssertEqual(filters,
                       #"{"tozeret_cd":"588","degem_cd":"12","sug_degem":"P","shnat_yitzur":"2008"}"#)
        XCTAssertNotEqual(limit, "1")
    }

    // MARK: - Not-found

    func testEmptyRecordsYieldNoRecord() throws {
        let data = try fixture("notfound")
        let response = try JSONDecoder().decode(DataGovResponse<Vehicle>.self, from: data)
        XCTAssertTrue(response.success)
        XCTAssertNil(response.result?.records?.first)
        XCTAssertTrue(response.result?.records?.isEmpty ?? true)
    }

    // MARK: - Endpoint URL

    func testEndpointFiltersByPlateAsString() throws {
        let url = DataGovEndpoint.searchURL(
            resourceID: DataGovEndpoint.primaryResourceID, plate: 5970065
        )
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let resource = comps.queryItems?.first { $0.name == "resource_id" }?.value
        let filters = comps.queryItems?.first { $0.name == "filters" }?.value
        XCTAssertEqual(resource, DataGovEndpoint.primaryResourceID)
        // The plate must be sent as a JSON string even though the field is numeric.
        XCTAssertEqual(filters, #"{"mispar_rechev":"5970065"}"#)
    }

    // MARK: - Validity parsing

    func testValidityStatusThresholds() {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 16
        components.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        let now = calendar.date(from: components)!

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "yyyy-MM-dd"

        let future = "2030-01-01"
        let soon = formatter.string(from: calendar.date(byAdding: .month, value: 1, to: now)!)
        let past = "2024-01-01"

        XCTAssertEqual(SearchViewModel.validity(of: future, now: now), .valid)
        XCTAssertEqual(SearchViewModel.validity(of: soon, now: now), .expiringSoon)
        XCTAssertEqual(SearchViewModel.validity(of: past, now: now), .expired)
        XCTAssertEqual(SearchViewModel.validity(of: nil, now: now), .unknown)
        XCTAssertEqual(SearchViewModel.validity(of: "not-a-date", now: now), .unknown)
    }

    // MARK: - Search history store

    func testHistoryRecordsDedupesAndCaps() {
        var store = SearchHistoryStore()
        store = store.recording(plate: 111111, at: Date())
        store = store.recording(plate: 222222, at: Date())
        // Re-recording 111111 moves it to the top and does not duplicate.
        store = store.recording(plate: 111111, at: Date())
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertEqual(store.entries.first?.plate, 111111)

        store = store.removing(plate: 222222)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertFalse(store.entries.contains { $0.plate == 222222 })
    }
}
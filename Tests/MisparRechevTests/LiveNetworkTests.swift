import XCTest
@testable import MisparRechev

/// Diagnostic integration tests that hit the LIVE data.gov.il API from inside
/// the simulator using the app's real `VehicleService`. They auto-skip when the
/// network is unavailable so the suite stays green offline.
final class LiveNetworkTests: XCTestCase {

    // MARK: - Service-level

    func testLiveLookupKnownPlate() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 5970065)
            XCTAssertEqual(result.vehicle.mispar_rechev, 5970065)
            print("✅ LIVE primary OK: \(result.vehicle.tozeret_nm ?? "?") / \(result.vehicle.kinuy_mishari ?? "?") | mileage=\(result.mileage != nil) ownership=\(result.ownership.count)")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// Plate 3256880 has a known ownership timeline: פרטי → סוחר → פרטי.
    func testLiveLookupOwnershipTimeline() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 3256880)
            XCTAssertEqual(result.vehicle.mispar_rechev, 3256880)
            XCTAssertFalse(result.ownership.isEmpty, "Expected an ownership timeline")
            // Ascending by baalut_dt, and all records belong to this plate.
            let dates = result.ownership.compactMap { $0.baalut_dt }
            XCTAssertEqual(dates, dates.sorted(), "Ownership must be ascending")
            XCTAssertTrue(result.ownership.allSatisfy { $0.mispar_rechev == 3256880 })
            let types = result.ownership.compactMap { $0.ownerType }
            print("✅ LIVE 3256880 ownership: \(types) | km=\(result.mileage?.mileageKm ?? "nil")")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// Regression for the user's imported plate 9441873 — a personally-imported
    /// Mercedes that lives in the `personal_import_vehicles` fallback dataset.
    func testLiveLookupImportedPlate9441873() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 9441873)
            XCTAssertEqual(result.vehicle.mispar_rechev, 9441873)
            XCTAssertEqual(result.vehicle.tozeret_nm, "מרצדס בנץ גרמנ")
            XCTAssertEqual(result.vehicle.importType, "יבוא אישי-משומש")
            XCTAssertEqual(result.vehicle.countryOfManufacture, "גרמניה")
            XCTAssertNotNil(result.vehicle.chassis)
            print("✅ LIVE 9441873 import OK: \(result.vehicle.tozeret_nm ?? "?") | \(result.vehicle.importType ?? "?") | \(result.vehicle.countryOfManufacture ?? "?")")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// Regression for the user's plate 77720101 — Mercedes whose
    /// `ramat_eivzur_betihuty` is the integer 2 (previously broke decoding).
    func testLiveLookupUserPlate77720101() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 77720101)
            XCTAssertEqual(result.vehicle.mispar_rechev, 77720101)
            XCTAssertEqual(result.vehicle.tozeret_nm, "מרצדס בנץ ד.אפ")
            XCTAssertEqual(result.vehicle.ramat_eivzur_betihuty, 2)
            print("✅ LIVE 77720101 OK: \(result.vehicle.tozeret_nm ?? "?") / \(result.vehicle.kinuy_mishari ?? "?") | ownership=\(result.ownership.count)")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// Verifies the public-vehicles fallback: this plate is a bus, absent from
    /// the primary private/commercial dataset but present in the public one.
    func testLiveLookupPublicVehicleFallback() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 17070204)
            XCTAssertEqual(result.vehicle.mispar_rechev, 17070204)
            XCTAssertEqual(result.vehicle.tozeret_nm, "הייגר סין")
            print("✅ LIVE public fallback OK: \(result.vehicle.tozeret_nm ?? "?") | year=\(result.vehicle.shnat_yitzur.map(String.init) ?? "?")")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// The new-car price join for 77720101 (C300E 2020, codes 1207/2/P/2020).
    /// Don't hard-assert the amount — the dataset updates; assert identity only.
    func testLiveNewCarPriceLookup() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 77720101)
            XCTAssertTrue(result.prices.allSatisfy {
                $0.tozeret_cd == result.vehicle.tozeret_cd && $0.degem_cd == result.vehicle.degem_cd
            })
            print("✅ LIVE 77720101 prices: \(result.prices.compactMap { $0.mehir })")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// Plate 5569379 had an open recall when this test was written. The recall
    /// dataset refreshes daily and the recall may get performed/closed, so only
    /// assert that whatever comes back belongs to the plate.
    func testLiveRecallLookup() async throws {
        let service = VehicleService()
        do {
            let result = try await service.lookup(plate: 5569379)
            XCTAssertEqual(result.vehicle.mispar_rechev, 5569379)
            XCTAssertTrue(result.recalls.allSatisfy { $0.MISPAR_RECHEV == 5569379 })
            print("✅ LIVE 5569379 recalls: \(result.recalls.count) | \(result.recalls.compactMap { $0.category })")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    /// A 9-digit "plate" matches nothing in any dataset → `.notFound`.
    func testLiveLookupNotFound() async throws {
        let service = VehicleService()
        do {
            _ = try await service.lookup(plate: 999999999)
            XCTFail("Expected .notFound for a non-existent plate")
        } catch VehicleError.notFound {
            print("✅ LIVE not-found OK (throws .notFound as expected)")
        } catch let error as VehicleError {
            try Self.handle(error)
        } catch {
            throw error
        }
    }

    // MARK: - ViewModel end-to-end

    @MainActor
    func testViewModelLiveLookupEndToEnd() async throws {
        let vm = SearchViewModel()
        vm.plateInput = "5970065"
        vm.search()
        for _ in 0..<150 where Self.isLoadingState(vm.state) {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        switch vm.state {
        case .loaded(let result):
            XCTAssertEqual(result.vehicle.mispar_rechev, 5970065)
            print("✅ VM end-to-end OK: \(result.vehicle.tozeret_nm ?? "?") | mileage=\(result.mileage != nil) ownership=\(result.ownership.count)")
        case .error(let error):
            try Self.handle(error)
        case .loading:
            XCTFail("ViewModel still loading after 15s")
        case .empty:
            XCTFail("ViewModel ended in empty state")
        }
    }

    @MainActor
    func testViewModelTwoSequentialLookups() async throws {
        let vm = SearchViewModel()

        vm.plateInput = "5970065"; vm.search()
        for _ in 0..<150 where Self.isLoadingState(vm.state) {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        guard case .loaded(let first) = vm.state else {
            if case .error(let e) = vm.state { try Self.handle(e) }
            XCTFail("First lookup failed: \(vm.state)"); return
        }
        let v1 = first.vehicle
        XCTAssertEqual(v1.mispar_rechev, 5970065)

        vm.reset()
        vm.plateInput = "3256880"; vm.search()
        for _ in 0..<150 where Self.isLoadingState(vm.state) {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        switch vm.state {
        case .loaded(let second):
            XCTAssertEqual(second.vehicle.mispar_rechev, 3256880)
            XCTAssertFalse(second.ownership.isEmpty)
            print("✅ Two-lookup OK: 1st=\(v1.mispar_rechev), 2nd=\(second.vehicle.mispar_rechev) ownership=\(second.ownership.count) km=\(second.mileage?.mileageKm ?? "nil")")
        case .error(let error):
            try Self.handle(error)
        default:
            XCTFail("Second lookup unexpected state: \(vm.state)")
        }
    }

    // MARK: - Helpers

    private static func isLoadingState(_ state: LookupState) -> Bool {
        if case .loading = state { return true } else { return false }
    }

    /// Network/transport errors → skip (don't fail) so the suite is robust
    /// offline. Genuine logic errors (notFound/decoding) still throw.
    private static func handle(_ error: VehicleError) throws {
        switch error {
        case .network:
            throw XCTSkip("Skipped (offline): \(error)")
        default:
            throw error
        }
    }
}
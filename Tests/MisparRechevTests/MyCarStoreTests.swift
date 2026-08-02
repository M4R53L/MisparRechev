import XCTest
@testable import MisparRechev

/// Pinned-car store: pin/round-trip/update/unpin against an isolated
/// UserDefaults suite (never the real app-group container).
final class MyCarStoreTests: XCTestCase {

    private let suiteName = "test.myCar"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPinRoundTripUpdateUnpin() {
        let pinDate = Date(timeIntervalSince1970: 1_700_000_000)
        var store = MyCarStore()
        XCTAssertNil(store.car)

        store = store.pinning(plate: 77720101, title: "C300E • 2020",
                              tokefDt: "2027-07-06", recallIDs: [15947],
                              at: pinDate)
        store.save(defaults: defaults)

        var loaded = MyCarStore.load(defaults: defaults)
        XCTAssertEqual(loaded, store)
        XCTAssertEqual(loaded.car?.plate, 77720101)
        XCTAssertEqual(loaded.car?.title, "C300E • 2020")
        XCTAssertEqual(loaded.car?.tokefDt, "2027-07-06")
        XCTAssertEqual(loaded.car?.knownRecallIDs, [15947])
        XCTAssertEqual(loaded.car?.lastRefreshed, pinDate)
        XCTAssertEqual(loaded.car?.pinnedAt, pinDate)

        let refreshDate = Date(timeIntervalSince1970: 1_800_000_000)
        loaded = loaded.updating(tokefDt: "2028-07-06",
                                 knownRecallIDs: [16000, 15947],
                                 refreshedAt: refreshDate)
        XCTAssertEqual(loaded.car?.tokefDt, "2028-07-06")
        XCTAssertEqual(loaded.car?.knownRecallIDs, [15947, 16000], "IDs stored sorted")
        XCTAssertEqual(loaded.car?.lastRefreshed, refreshDate)
        XCTAssertEqual(loaded.car?.title, "C300E • 2020", "updating keeps identity fields")
        XCTAssertEqual(loaded.car?.pinnedAt, pinDate)

        loaded = loaded.unpinning()
        XCTAssertNil(loaded.car)
        loaded.save(defaults: defaults)
        XCTAssertNil(MyCarStore.load(defaults: defaults).car)
    }

    func testUpdatingWithoutPinnedCarIsNoop() {
        let store = MyCarStore().updating(tokefDt: "2027-01-01",
                                          knownRecallIDs: [1],
                                          refreshedAt: .now)
        XCTAssertNil(store.car)
    }

    func testLoadReturnsEmptyStoreOnMissingData() {
        XCTAssertNil(MyCarStore.load(defaults: defaults).car)
    }
}

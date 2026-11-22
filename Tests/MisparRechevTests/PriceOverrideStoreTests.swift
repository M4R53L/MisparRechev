import XCTest
@testable import MisparRechev

final class PriceOverrideStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "PriceOverrideStoreTests")
        defaults.removePersistentDomain(forName: "PriceOverrideStoreTests")
    }

    func testStoresAndReadsBackAValue() {
        let store = PriceOverrideStore().setting(87_500, for: 5_970_065)
        XCTAssertEqual(store.value(for: 5_970_065), 87_500)
        XCTAssertNil(store.value(for: 1_234_567))
    }

    func testSettingNilOrZeroClearsTheOverride() {
        let store = PriceOverrideStore().setting(87_500, for: 5_970_065)
        XCTAssertNil(store.setting(nil, for: 5_970_065).value(for: 5_970_065))
        XCTAssertNil(store.setting(0, for: 5_970_065).value(for: 5_970_065))
        XCTAssertNil(store.removing(plate: 5_970_065).value(for: 5_970_065))
    }

    func testLatestValueWinsPerPlate() {
        let store = PriceOverrideStore()
            .setting(80_000, for: 5_970_065)
            .setting(91_000, for: 5_970_065)
        XCTAssertEqual(store.overrides.count, 1)
        XCTAssertEqual(store.value(for: 5_970_065), 91_000)
    }

    func testRoundTripsThroughUserDefaults() {
        PriceOverrideStore().setting(64_000, for: 3_256_880).save(defaults: defaults)
        XCTAssertEqual(PriceOverrideStore.load(defaults: defaults).value(for: 3_256_880), 64_000)
    }

    func testLoadReturnsEmptyStoreWhenNothingPersisted() {
        XCTAssertEqual(PriceOverrideStore.load(defaults: defaults), PriceOverrideStore())
    }

    func testCapsStoredOverridesKeepingTheNewest() {
        var store = PriceOverrideStore()
        let start = Date(timeIntervalSince1970: 0)
        for index in 0...PriceOverrideStore.maxEntries {
            store = store.setting(1_000 + index,
                                  for: index,
                                  at: start.addingTimeInterval(Double(index)))
        }
        XCTAssertEqual(store.overrides.count, PriceOverrideStore.maxEntries)
        XCTAssertNil(store.value(for: 0), "oldest edit should be dropped")
        XCTAssertEqual(store.value(for: PriceOverrideStore.maxEntries),
                       1_000 + PriceOverrideStore.maxEntries)
    }
}

import XCTest
@testable import MisparRechev

/// Deterministic tests for the depreciation estimate — `now` is injected so
/// results don't drift with the calendar.
final class PriceEstimatorTests: XCTestCase {

    /// 2026-07-01 in Asia/Jerusalem.
    private let now: Date = {
        var components = DateComponents()
        components.year = 2026; components.month = 7; components.day = 1
        components.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        return Calendar(identifier: .gregorian).date(from: components)!
    }()

    func testOneYearOldLosesFifteenPercent() {
        XCTAssertEqual(
            PriceEstimator.estimatedValue(newPrice: 100_000, productionYear: 2025, now: now),
            85_000
        )
    }

    func testThreeYearsOldCompoundsTenPercentPerExtraYear() {
        // 100,000 × 0.85 × 0.9² = 68,850 → rounds to 69,000.
        XCTAssertEqual(
            PriceEstimator.estimatedValue(newPrice: 100_000, productionYear: 2023, now: now),
            69_000
        )
    }

    func testVeryOldCarFlooredAtFivePercent() {
        // 30 years: 0.85 × 0.9²⁹ ≈ 4% → clamped to 5,000.
        XCTAssertEqual(
            PriceEstimator.estimatedValue(newPrice: 100_000, productionYear: 1996, now: now),
            5_000
        )
    }

    func testCurrentYearCarHasNoEstimate() {
        XCTAssertNil(PriceEstimator.estimatedValue(newPrice: 100_000, productionYear: 2026, now: now))
        XCTAssertNil(PriceEstimator.estimatedValue(newPrice: 100_000, productionYear: 2027, now: now))
    }

    func testNonPositivePriceHasNoEstimate() {
        XCTAssertNil(PriceEstimator.estimatedValue(newPrice: 0, productionYear: 2020, now: now))
    }

    func testFormattedGroupsThousands() {
        XCTAssertEqual(PriceEstimator.formatted(375_900), "375,900 ₪")
        XCTAssertEqual(PriceEstimator.formatted(500), "500 ₪")
    }
}

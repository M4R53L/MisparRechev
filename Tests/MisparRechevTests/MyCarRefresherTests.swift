import XCTest
@testable import MisparRechev

/// Pure decision logic of the my-car refresher: reminder scheduling dates and
/// new-recall detection. (The notification/BG plumbing is thin Apple API.)
final class MyCarRefresherTests: XCTestCase {

    /// Fixed "now": 2026-08-02 12:00 Asia/Jerusalem.
    private var now: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 2
        components.hour = 12
        components.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    func testReminderDatesForFarFutureTokef() {
        let reminders = MyCarRefresher.reminderDates(tokefDt: "2027-05-24", now: now)
        XCTAssertEqual(reminders.map { $0.daysBefore }, [30, 7, 0])
        for reminder in reminders {
            XCTAssertEqual(reminder.components.hour, 9)
            XCTAssertEqual(reminder.components.minute, 0)
        }
        let dayOf = reminders.first { $0.daysBefore == 0 }!.components
        XCTAssertEqual([dayOf.year, dayOf.month, dayOf.day], [2027, 5, 24])
        let thirty = reminders.first { $0.daysBefore == 30 }!.components
        XCTAssertEqual([thirty.year, thirty.month, thirty.day], [2027, 4, 24])
    }

    func testReminderDatesNearExpiryDropPastOffsets() {
        // Expiry 5 days out → the 30- and 7-day reminders are already past.
        let reminders = MyCarRefresher.reminderDates(tokefDt: "2026-08-07", now: now)
        XCTAssertEqual(reminders.map { $0.daysBefore }, [0])
    }

    func testReminderDatesEmptyForPastNilOrUnparseable() {
        XCTAssertTrue(MyCarRefresher.reminderDates(tokefDt: "2024-01-01", now: now).isEmpty)
        XCTAssertTrue(MyCarRefresher.reminderDates(tokefDt: nil, now: now).isEmpty)
        XCTAssertTrue(MyCarRefresher.reminderDates(tokefDt: "not-a-date", now: now).isEmpty)
    }

    func testNewRecallIDsDiff() {
        func recall(_ id: Int?) -> RecallRecord {
            RecallRecord(MISPAR_RECHEV: 1, RECALL_ID: id, SUG_RECALL: nil,
                         SUG_TAKALA: nil, TEUR_TAKALA: nil, TAARICH_PTICHA: nil)
        }
        XCTAssertEqual(
            MyCarRefresher.newRecallIDs(fetched: [recall(1), recall(2), recall(3)],
                                        known: [2]),
            [1, 3])
        XCTAssertEqual(
            MyCarRefresher.newRecallIDs(fetched: [recall(nil), recall(7)], known: []),
            [7], "records without an ID are ignored")
        XCTAssertTrue(MyCarRefresher.newRecallIDs(fetched: [], known: [1, 2]).isEmpty)
        XCTAssertTrue(
            MyCarRefresher.newRecallIDs(fetched: [recall(1)], known: [1]).isEmpty)
    }
}

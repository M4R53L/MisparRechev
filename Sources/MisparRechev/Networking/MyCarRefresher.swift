import BackgroundTasks
import Foundation
import UserNotifications
import WidgetKit

/// Single refresh pipeline for the pinned "הרכב שלי": fetch → persist store →
/// reschedule test-expiry reminders → notify newly opened recalls → reload
/// widget timelines. Shared by BGAppRefresh, foreground activation and the
/// pin-time seeding path.
final class MyCarRefresher {
    static let shared = MyCarRefresher()
    static let taskIdentifier = "il.misparrechev.app.refresh"

    /// Foreground activations refresh at most this often; also the earliest
    /// begin date requested for the background task.
    static let minRefreshInterval: TimeInterval = 12 * 3600

    private static let testReminderIDs = ["myCar.test.30", "myCar.test.7", "myCar.test.0"]

    private let service = VehicleService()

    private init() {}

    // MARK: - Refresh entry points

    /// Foreground path: refresh only when the last refresh is old enough.
    func refreshIfNeeded(now: Date = .now) async {
        guard let car = MyCarStore.load().car else { return }
        if let last = car.lastRefreshed,
           now.timeIntervalSince(last) < Self.minRefreshInterval { return }
        await refresh()
    }

    /// Unconditional refresh of the pinned car (no-op when nothing is pinned
    /// or the lookup fails — the stale status simply survives).
    func refresh() async {
        let store = MyCarStore.load()
        guard let car = store.car else { return }
        guard let result = try? await service.lookup(plate: car.plate) else { return }
        apply(result: result, for: car, in: store, notifyNewRecalls: true)
    }

    /// Pin-time path: the result was just fetched live, so seed notifications
    /// and the store from it without a second network call. Recalls already
    /// visible on screen are seeded as known — not notified.
    func applyPinned(result: LookupResult) {
        let store = MyCarStore.load()
        guard let car = store.car, car.plate == result.vehicle.mispar_rechev else { return }
        apply(result: result, for: car, in: store, notifyNewRecalls: false)
    }

    private func apply(result: LookupResult, for car: MyCarStore.PinnedCar,
                       in store: MyCarStore, notifyNewRecalls: Bool) {
        if notifyNewRecalls {
            let newIDs = Set(Self.newRecallIDs(fetched: result.recalls,
                                               known: car.knownRecallIDs))
            for recall in result.recalls
            where recall.RECALL_ID.map(newIDs.contains) == true {
                notifyRecall(recall, plate: car.plate)
            }
        }

        scheduleTestReminders(tokefDt: result.vehicle.tokef_dt, title: car.title)

        // `knownRecallIDs` become the currently-open set — a performed recall
        // drops out, so the card count always reflects open recalls.
        store.updating(tokefDt: result.vehicle.tokef_dt,
                       knownRecallIDs: result.recalls.compactMap { $0.RECALL_ID },
                       refreshedAt: .now)
            .save()
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Background task scheduling

    /// Submits the next background refresh request — only while a car is
    /// pinned, so an unpinned app stops waking up.
    static func scheduleAppRefresh() {
        guard MyCarStore.load().car != nil else { return }
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minRefreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    // MARK: - Notifications

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func cancelAllMyCarNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.testReminderIDs)
        center.removeAllDeliveredNotifications()
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Replaces the three test-expiry reminders (30/7/0 days before, 09:00)
    /// with ones derived from the latest known expiry date.
    private func scheduleTestReminders(tokefDt: String?, title: String) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: Self.testReminderIDs)

        let reminders = Self.reminderDates(tokefDt: tokefDt)
        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = "תוקף הטסט מתקרב"
            content.body = reminder.daysBefore == 0
                ? "הטסט של \(title) פג היום. זכרו לחדש"
                : "הטסט של \(title) יפוג בעוד \(reminder.daysBefore) ימים"
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: reminder.components,
                                                       repeats: false)
            center.add(UNNotificationRequest(identifier: "myCar.test.\(reminder.daysBefore)",
                                             content: content, trigger: trigger))
        }
        #if DEBUG
        print("🔔 my-car test reminders scheduled: \(reminders.map { $0.daysBefore }) days before \(tokefDt ?? "-")")
        #endif
    }

    /// Immediate local notification for a newly opened recall.
    private func notifyRecall(_ recall: RecallRecord, plate: Int) {
        let content = UNMutableNotificationContent()
        content.title = "ריקול חדש לרכב שלך"
        let what = [recall.category, recall.details].compactMap { $0 }.joined(separator: " — ")
        content.body = what.isEmpty
            ? "נפתחה קריאת שירות לרכב \(plate). פרטים אצל היבואן"
            : what
        content.sound = .default
        let identifier = "myCar.recall.\(recall.RECALL_ID ?? plate)"
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
        #if DEBUG
        print("🔔 my-car recall notification: \(identifier)")
        #endif
    }

    // MARK: - Pure helpers (unit-tested)

    /// Reminder fire dates for a test expiry: 30/7/0 days before at 09:00
    /// Asia/Jerusalem — future dates only. Empty for absent/unparseable/past
    /// expiry strings.
    static func reminderDates(tokefDt: String?, now: Date = .now)
        -> [(daysBefore: Int, components: DateComponents)] {
        guard let tokefDt, let expiry = SearchViewModel.parse(tokefDt) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        let timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current
        calendar.timeZone = timeZone

        return [30, 7, 0].compactMap { daysBefore in
            guard let base = calendar.date(byAdding: .day, value: -daysBefore, to: expiry) else {
                return nil
            }
            var components = calendar.dateComponents([.year, .month, .day], from: base)
            components.hour = 9
            components.minute = 0
            components.timeZone = timeZone
            guard let fireDate = calendar.date(from: components), fireDate > now else {
                return nil
            }
            return (daysBefore, components)
        }
    }

    /// Recall IDs present in `fetched` but not yet known (i.e. newly opened).
    static func newRecallIDs(fetched: [RecallRecord], known: [Int]) -> [Int] {
        let knownSet = Set(known)
        return fetched.compactMap { $0.RECALL_ID }.filter { !knownSet.contains($0) }
    }
}

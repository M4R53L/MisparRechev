import WidgetKit

struct MyCarEntry: TimelineEntry {
    let date: Date
    let car: MyCarStore.PinnedCar?
}

/// Renders whatever the shared store holds. One entry, refreshed daily — the
/// app pushes fresher data with `WidgetCenter.reloadAllTimelines()` after
/// every my-car refresh, so the daily policy is just a backstop.
struct MyCarTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MyCarEntry {
        MyCarEntry(date: .now,
                   car: MyCarStore.PinnedCar(plate: 12345678, title: "הרכב שלי",
                                             tokefDt: nil, knownRecallIDs: [],
                                             lastRefreshed: nil, pinnedAt: .now))
    }

    func getSnapshot(in context: Context, completion: @escaping (MyCarEntry) -> Void) {
        completion(MyCarEntry(date: .now, car: MyCarStore.load().car))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MyCarEntry>) -> Void) {
        let entry = MyCarEntry(date: .now, car: MyCarStore.load().car)
        let nextRefresh = Date(timeIntervalSinceNow: 24 * 3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

import SwiftUI
import WidgetKit

@main
struct MisparRechevWidgetBundle: WidgetBundle {
    var body: some Widget {
        MyCarWidget()
    }
}

/// "הרכב שלי" — the pinned car's plate, test expiry and days-left status,
/// fed from the App-Group `MyCarStore` the app refreshes.
struct MyCarWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MyCarWidget", provider: MyCarTimelineProvider()) { entry in
            MyCarWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "he_IL"))
        }
        .configurationDisplayName("הרכב שלי")
        .description("תוקף הטסט וסטטוס הרכב המוצמד")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

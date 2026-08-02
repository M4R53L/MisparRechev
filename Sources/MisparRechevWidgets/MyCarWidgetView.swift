import SwiftUI
import WidgetKit

/// Widget-local theme — hex constants copied from the app's `Theme` (the
/// app's DesignSystem is deliberately not compiled into the extension).
enum WidgetTheme {
    static let plateYellow = Color(red: 0xFA / 255, green: 0xD2 / 255, blue: 0x01 / 255)
    static let plateText = Color(red: 0x10 / 255, green: 0x10 / 255, blue: 0x10 / 255)
    static let success = Color(red: 0x2B / 255, green: 0xA8 / 255, blue: 0x4A / 255)
    static let warning = Color(red: 0xE6 / 255, green: 0xA7 / 255, blue: 0x00 / 255)
    static let danger = Color(red: 0xD9 / 255, green: 0x35 / 255, blue: 0x2B / 255)
}

struct MyCarWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MyCarEntry

    var body: some View {
        Group {
            if let car = entry.car {
                content(car)
            } else {
                placeholderView
            }
        }
        .widgetURL(URL(string: "misparrechev://my-car"))
    }

    // MARK: - Pinned content

    @ViewBuilder
    private func content(_ car: MyCarStore.PinnedCar) -> some View {
        switch family {
        case .systemMedium:
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    plateChip(car.plate)
                    Text(car.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if let refreshed = car.lastRefreshed {
                        Text("עודכן \(relative(refreshed))")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
                testStatus(car, large: true)
            }
        default:
            VStack(alignment: .leading, spacing: 6) {
                header
                plateChip(car.plate)
                Text(car.title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                testStatus(car, large: false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("הרכב שלי")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.secondary)
    }

    private func plateChip(_ plate: Int) -> some View {
        Text(String(plate))
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(WidgetTheme.plateText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(WidgetTheme.plateYellow))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(WidgetTheme.plateText, lineWidth: 1))
    }

    @ViewBuilder
    private func testStatus(_ car: MyCarStore.PinnedCar, large: Bool) -> some View {
        if let tokef = car.tokefDt, let expiry = PlateDates.parse(tokef) {
            let days = daysLeft(until: expiry)
            VStack(alignment: large ? .center : .leading, spacing: 2) {
                if large {
                    Text(daysText(days))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(statusColor(car.tokefDt))
                    Text("טסט עד \(shortDate(expiry))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                } else {
                    Text("טסט עד \(shortDate(expiry))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(daysText(days))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(statusColor(car.tokefDt))
                }
            }
        } else {
            Text("תוקף טסט לא ידוע")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty state

    private var placeholderView: some View {
        VStack(spacing: 6) {
            Image(systemName: "star")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("הצמידו רכב באפליקציה")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func daysLeft(until expiry: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
                                       from: calendar.startOfDay(for: entry.date),
                                       to: calendar.startOfDay(for: expiry)).day ?? 0
    }

    private func daysText(_ days: Int) -> String {
        switch days {
        case ..<0: return "פג לפני \(-days) ימים"
        case 0: return "פג היום"
        case 1: return "נותר יום אחד"
        default: return "נותרו \(days) ימים"
        }
    }

    private func statusColor(_ tokefDt: String?) -> Color {
        switch PlateDates.validity(of: tokefDt, now: entry.date) {
        case .valid: return WidgetTheme.success
        case .expiringSoon: return WidgetTheme.warning
        case .expired: return WidgetTheme.danger
        case .unknown: return .secondary
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "d.M.yyyy"
        return formatter.string(from: date)
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: entry.date)
    }
}

#Preview(as: .systemSmall) {
    MyCarWidget()
} timeline: {
    MyCarEntry(date: .now,
               car: MyCarStore.PinnedCar(plate: 77720101, title: "C300E • 2020",
                                         tokefDt: "2027-07-06", knownRecallIDs: [],
                                         lastRefreshed: .now, pinnedAt: .now))
    MyCarEntry(date: .now, car: nil)
}

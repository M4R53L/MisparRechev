import SwiftUI

/// "הרכב שלי" status card on the search screen: pinned plate + title, the
/// test-expiry badge, and the open-recall status as of the last refresh.
/// Tapping opens the car's report (snapshot-first).
struct MyCarCard: View {
    let car: MyCarStore.PinnedCar
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "star.fill")
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.Colors.plateYellow)
                        .accessibilityHidden(true)
                    Text("הרכב שלי")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    if let refreshed = car.lastRefreshed {
                        Text("עודכן \(relative(refreshed))")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textTertiary)
                    }
                }

                HStack(spacing: Theme.Spacing.m) {
                    PlateView(number: String(car.plate), size: .compact)
                    Text(car.title)
                        .font(Theme.Typography.bodyBold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                HStack {
                    Text("תוקף טסט")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    Spacer(minLength: Theme.Spacing.s)
                    StatusBadge(dateString: car.tokefDt,
                                status: SearchViewModel.validity(of: car.tokefDt))
                }

                HStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: car.knownRecallIDs.isEmpty
                          ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(recallsText)
                        .font(Theme.Typography.captionBold)
                }
                .foregroundStyle(car.knownRecallIDs.isEmpty
                                 ? Theme.Colors.success : Theme.Colors.danger)
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("הרכב שלי: \(car.title)")
        .accessibilityHint("פתיחת דוח הרכב")
    }

    private var recallsText: String {
        switch car.knownRecallIDs.count {
        case 0: return "אין ריקולים פתוחים"
        case 1: return "ריקול פתוח אחד"
        default: return "\(car.knownRecallIDs.count) ריקולים פתוחים"
        }
    }

    private func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack(spacing: 16) {
        MyCarCard(car: .init(plate: 77720101, title: "C300E • 2020",
                             tokefDt: "2027-07-06", knownRecallIDs: [],
                             lastRefreshed: .now, pinnedAt: .now)) {}
        MyCarCard(car: .init(plate: 5569379, title: "RIO • 2012",
                             tokefDt: "2026-08-20", knownRecallIDs: [15947],
                             lastRefreshed: .now.addingTimeInterval(-90_000),
                             pinnedAt: .now)) {}
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

import SwiftUI

/// Danger-styled banner for a vehicle in "ביטול סופי" status — it was taken
/// off the road for good. Mirrors `RecallWarningView`'s danger chrome.
struct DeregisteredBannerView: View {
    /// Raw `bitul_dt` API string ("2026-07-30 00:00:00"); formatted for display.
    let bitulDate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.danger)
                    .accessibilityHidden(true)
                Text("ירד מהכביש (ביטול סופי)")
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.danger)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, Theme.Spacing.xs)

            if let formatted = SearchViewModel.displayDate(bitulDate) ?? bitulDate, !formatted.isEmpty {
                InfoRow(label: "תאריך ביטול", value: formatted, monospaced: true)
            }

            Text("הרכב אינו רשום עוד לתנועה; הנתונים המוצגים הם הרשומה האחרונה שנשמרה במאגר")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Colors.danger.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Theme.Colors.danger, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    DeregisteredBannerView(bitulDate: "2026-07-30 00:00:00")
        .padding()
        .background(Theme.Colors.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

import SwiftUI

/// Grouped card container used by `ResultView` to hold related info rows.
struct InfoCard<Content: View>: View {
    let title: String
    /// Optional SF Symbol shown next to the title.
    var systemImage: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Colors.primary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, Theme.Spacing.xs)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                content()
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Theme.Colors.divider.opacity(0.5), lineWidth: 0.5)
        )
        .cardShadow()
    }
}

#Preview {
    InfoCard(title: "פרטים בסיסיים", systemImage: "car.fill") {
        Text("גוף התוכן כאן")
            .font(Theme.Typography.body)
            .foregroundStyle(Theme.Colors.textSecondary)
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

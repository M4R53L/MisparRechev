import SwiftUI

/// A titled group of related rows: the title sits on the page background,
/// the rows on one flat surface (the iOS grouped-list idiom).
struct InfoCard<Content: View>: View {
    let title: String
    /// Optional SF Symbol shown next to the title.
    var systemImage: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(.subheadline, weight: .semibold))
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Theme.Spacing.xs)
            .accessibilityAddTraits(.isHeader)

            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                content()
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
        }
    }
}

#Preview {
    InfoCard(title: "הרכב", systemImage: "car.fill") {
        InfoRow(label: "יצרן", value: "מזדה")
        InfoRow(label: "רמת גימור", value: "S")
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

import SwiftUI

/// Loading screen — `ProgressView` + shimmering grouped cards.
struct LoadingView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.l) {
                header

                SkeletonCard(rowCount: 4)
                SkeletonCard(rowCount: 3)
                SkeletonCard(rowCount: 3)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("טוען פרטי רכב")
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.s) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.primary)
            Text("מחפש רכב…")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
            Text("מושך נתונים ממאגרי משרד התחבורה")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.l)
    }
}

#Preview {
    LoadingView()
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

import SwiftUI

/// Danger-styled card listing the vehicle's open, unperformed recalls.
/// Rendered only when there is at least one recall — mirrors `InfoCard`'s
/// layout tokens but with danger coloring so it stands out.
struct RecallWarningView: View {
    let recalls: [RecallRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Colors.danger)
                    .accessibilityHidden(true)
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundStyle(Theme.Colors.danger)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.bottom, Theme.Spacing.xs)

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(recalls) { recall in
                    recallRow(recall)
                    if recall.id != recalls.last?.id {
                        Divider().padding(.vertical, Theme.Spacing.xs)
                    }
                }
            }

            Text("יש לפנות ליבואן לתיאום הטיפול")
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, Theme.Spacing.xs)
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

    private var title: String {
        recalls.count > 1 ? "\(recalls.count) ריקולים פתוחים" : "ריקול פתוח"
    }

    @ViewBuilder
    private func recallRow(_ recall: RecallRecord) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let category = recall.category {
                Text(category)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            if let details = recall.details {
                Text(details)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            if let opened = SearchViewModel.displayDate(recall.TAARICH_PTICHA) {
                Text("נפתח ב־\(opened)")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }
        }
    }
}

#Preview {
    RecallWarningView(recalls: [.preview])
        .padding()
        .background(Theme.Colors.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

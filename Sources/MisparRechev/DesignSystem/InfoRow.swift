import SwiftUI

/// A horizontal label/value row inside an `InfoCard`.
/// - Label leading (right in RTL) in muted color.
/// - Value trailing (left in RTL) in primary text.
/// - Hides itself when `value` is `nil`.
struct InfoRow: View {
    let label: String
    let value: String?
    var unit: String? = nil
    /// Optional SF Symbol shown to the right of the label (left in RTL).
    var systemImage: String? = nil
    /// When true, value is shown in a monospaced font.
    var monospaced: Bool = false

    var body: some View {
        if let value, !value.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.Colors.textTertiary)
                            .accessibilityHidden(true)
                    }
                    Text(label)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: Theme.Spacing.s)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(monospaced ? Theme.Typography.monoValue : Theme.Typography.bodyBold)
                        .foregroundStyle(Theme.Colors.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                    if let unit {
                        Text(unit)
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                }
            }
            .padding(.vertical, 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label): \(value)\(unit.map { " \($0)" } ?? "")")
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        InfoRow(label: "יצרן", value: "מזדה", systemImage: "wrench.and.screwdriver")
        InfoRow(label: "נפח מנוע", value: "1999", unit: "סמ״ק", monospaced: true)
        InfoRow(label: "צבע", value: nil) // hidden
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

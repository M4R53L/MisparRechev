import SwiftUI

/// Pill badge showing a date and a validity status.
///
/// Status text (Hebrew) + a colored capsule + a small dot.
struct StatusBadge: View {
    let dateString: String?
    let status: ValidityStatus

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            // Date first in RTL (reads right→left, so dot will end up on the right
            // because we set semantic foreground/background ordering).
            Text(displayedDate)
                .font(Theme.Typography.bodyBold)
                .foregroundStyle(Theme.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            statusPill
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusLabel), \(displayedDate)")
    }

    private var displayedDate: String {
        if let formatted = SearchViewModel.displayDate(dateString) {
            return formatted
        }
        return dateString?.isEmpty == false ? dateString! : "—"
    }

    private var statusPill: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(for: status))
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .font(Theme.Typography.captionBold)
                .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule().fill(color(for: status).opacity(0.18))
        )
        .overlay(
            Capsule().strokeBorder(color(for: status).opacity(0.35), lineWidth: 0.5)
        )
    }

    private var statusLabel: String {
        switch status {
        case .valid:        return "בתוקף"
        case .expiringSoon: return "עומד לפוג"
        case .expired:      return "פג תוקף"
        case .unknown:      return "לא ידוע"
        }
    }

    private func color(for s: ValidityStatus) -> Color {
        switch s {
        case .valid:        return Theme.Colors.success
        case .expiringSoon: return Theme.Colors.warning
        case .expired:      return Theme.Colors.danger
        case .unknown:      return Theme.Colors.neutral
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusBadge(dateString: "2026-12-31", status: .valid)
        StatusBadge(dateString: "2025-11-15", status: .expiringSoon)
        StatusBadge(dateString: "2024-01-01", status: .expired)
        StatusBadge(dateString: nil,         status: .unknown)
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

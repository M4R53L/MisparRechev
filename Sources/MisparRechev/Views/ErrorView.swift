import SwiftUI

/// Friendly error screen with a retry CTA. Different visuals per error type.
struct ErrorView: View {
    @Bindable var viewModel: SearchViewModel
    let error: VehicleError

    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: Theme.Spacing.xl)

            illustration

            VStack(spacing: Theme.Spacing.s) {
                Text(headline)
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                Text(error.errorDescription ?? "אירעה שגיאה לא צפויה")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.l)
            }

            actions

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    // MARK: - Subviews

    private var illustration: some View {
        Image(systemName: symbolName)
            .font(.system(size: 56, weight: .semibold))
            .foregroundStyle(tint)
            .symbolRenderingMode(.hierarchical)
            .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: Theme.Spacing.m) {
            Button {
                viewModel.search()
            } label: {
                Label("ניסיון נוסף", systemImage: "arrow.clockwise")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.canSearch)
            .accessibilityHint("מנסה שוב את אותו החיפוש")

            Button("חיפוש חדש") {
                viewModel.reset()
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityHint("חוזר למסך החיפוש הראשי")
        }
        .padding(.top, Theme.Spacing.m)
    }

    // MARK: - Style variants

    private var symbolName: String {
        switch error {
        case .notFound:        return "magnifyingglass"
        case .invalidPlate:    return "number"
        case .network:         return "wifi.exclamationmark"
        case .decoding, .server: return "exclamationmark.triangle"
        }
    }

    private var headline: String {
        switch error {
        case .notFound:        return "הרכב לא נמצא"
        case .invalidPlate:    return "מספר רישוי לא תקין"
        case .network:         return "אין חיבור לרשת"
        case .decoding:        return "שגיאת נתונים"
        case .server:          return "תקלה זמנית בשירות"
        }
    }

    private var tint: Color {
        switch error {
        case .notFound, .invalidPlate: return Theme.Colors.neutral
        case .network, .decoding, .server: return Theme.Colors.danger
        }
    }
}

#Preview {
    ErrorView(viewModel: SearchViewModel(), error: .notFound)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

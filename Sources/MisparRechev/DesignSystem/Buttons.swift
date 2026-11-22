import SwiftUI

/// Filled primary action. One per screen.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.textOnPrimary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(isEnabled ? Theme.Colors.primary : Theme.Colors.neutral.opacity(0.55))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Tinted secondary action: quieter than primary, no outline.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.headline)
            .foregroundStyle(Theme.Colors.primary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Colors.primary.opacity(configuration.isPressed ? 0.20 : 0.12))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// The onboarding action: a plate-yellow key that physically presses down
/// onto its dark base.
struct PlateKeyButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(.system(.title3, weight: .bold))
            .foregroundStyle(Theme.Colors.textOnPlate.opacity(isEnabled ? 1 : 0.45))
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Colors.plateYellow)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(Theme.Colors.plateBorder, lineWidth: 2)
            )
            .offset(y: pressed ? depth : 0)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Colors.plateBorder)
                    .offset(y: depth)
            )
            .padding(.bottom, depth)
            .saturation(isEnabled ? 1 : 0.4)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

import SwiftUI
import UIKit

// MARK: - Color hex helper (fileprivate)
private extension Color {
    /// Build a `Color` from a 24-bit RGB hex literal e.g. 0x1E5BB8.
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Dynamic light/dark Color built from two `Color` values.
    init(light: Color, dark: Color) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }
}

/// Centralised design tokens for the `מספר רכב` app.
enum Theme {

    // MARK: Colors
    enum Colors {
        // Primary — Israeli blue
        /// #1E5BB8 (light) / #5A8AD6 (dark) — used for buttons, links, app tint.
        static let primary: Color = .init(
            light: .init(hex: 0x1E5BB8),
            dark:  .init(hex: 0x5A8AD6)
        )

        /// System background. RootView uses this as the full-screen background.
        static let background: Color = Color(.systemBackground)

        /// Card / grouped surface.
        static let surface: Color = Color(.secondarySystemBackground)

        /// Slightly elevated surface (sheets, popovers).
        static let surfaceElevated: Color = Color(.tertiarySystemBackground)

        // Text
        static let textPrimary: Color   = Color(.label)
        static let textSecondary: Color = Color(.secondaryLabel)
        static let textTertiary: Color  = Color(.tertiaryLabel)
        static let textOnPrimary: Color = .white
        static let textOnPlate: Color   = .init(hex: 0x101010) // near-black on yellow

        // Israeli license plate
        /// #FAD201 — the iconic Israeli plate yellow.
        static let plateYellow: Color = .init(light: .init(hex: 0xFAD201),
                                             dark:  .init(hex: 0xD9B400))
        /// Black border around the yellow plate.
        static let plateBorder: Color = .init(hex: 0x101010)

        // Semantic
        static let success: Color = .init(light: .init(hex: 0x2BA84A),
                                          dark:  .init(hex: 0x4FD16A))
        static let warning: Color = .init(light: .init(hex: 0xE6A700),
                                          dark:  .init(hex: 0xFFC54A))
        static let danger:  Color = .init(light: .init(hex: 0xD9352B),
                                          dark:  .init(hex: 0xF26A60))
        static let neutral: Color = .init(light: .init(hex: 0x8E8E93),
                                          dark:  .init(hex: 0x9A9AA0))

        /// Divider hairlines on cards.
        static let divider: Color = Color(.separator)

        /// Subtle card shadow.
        static let cardShadow: Color = .init(light: .black.opacity(0.06),
                                             dark:  .black.opacity(0.30))
    }

    // MARK: Motion
    enum Motion {
        /// Default in/out animation duration.
        static let durationStandard: Double = 0.25
        static let durationSlow:     Double = 0.40
        /// Skeleton shimmer cycle.
        static let shimmerDuration:  Double = 1.5
    }

    // MARK: Spacing
    enum Spacing {
        static let xs:  CGFloat = 4
        static let s:   CGFloat = 8
        static let m:   CGFloat = 12
        static let l:   CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: Radius
    enum Radius {
        static let small:  CGFloat = 8
        static let medium: CGFloat = 12
        static let large:  CGFloat = 16
        static let plate:  CGFloat = 10
    }

    // MARK: Typography
    enum Typography {
        static let largeTitle:  Font = .system(size: 34, weight: .bold,         design: .default)
        static let title:       Font = .system(size: 24, weight: .bold,         design: .default)
        static let headline:    Font = .system(size: 18, weight: .semibold,     design: .default)
        static let body:        Font = .system(size: 16, weight: .regular,      design: .default)
        static let bodyBold:    Font = .system(size: 16, weight: .semibold,     design: .default)
        static let caption:     Font = .system(size: 13, weight: .regular,      design: .default)
        static let captionBold: Font = .system(size: 13, weight: .semibold,     design: .default)
        static let monoValue:   Font = .system(size: 15, weight: .medium,       design: .monospaced)

        /// Special font for the yellow plate: large, rounded, monospaced.
        static let plate:       Font = .system(size: 30, weight: .heavy,
                                                design: .rounded).monospacedDigit()
    }
}

// MARK: - Shadow helper
extension View {
    /// Standard soft card shadow.
    func cardShadow() -> some View {
        self.shadow(color: Theme.Colors.cardShadow,
                    radius: 8, x: 0, y: 2)
    }
}

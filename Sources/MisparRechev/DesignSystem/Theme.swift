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
        static let background: Color = Color(.systemGroupedBackground)

        /// Card / grouped surface (white on the grouped background in light mode).
        static let surface: Color = Color(.secondarySystemGroupedBackground)

        /// Slightly elevated surface (sheets, popovers).
        static let surfaceElevated: Color = Color(.tertiarySystemGroupedBackground)

        /// The blue band on the left edge of an Israeli plate. Same in both
        /// modes: it is a physical object, not interface chrome.
        static let plateStrip: Color = .init(hex: 0x1B4AA0)

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
        static let cardShadow: Color = .init(light: .black.opacity(0.10),
                                             dark:  .black.opacity(0.35))
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
    /// All tokens are built on text styles so they follow Dynamic Type.
    enum Typography {
        static let largeTitle:  Font = .system(.largeTitle, weight: .bold)
        static let title:       Font = .system(.title2, weight: .bold)
        static let headline:    Font = .system(.headline, weight: .semibold)
        static let body:        Font = .system(.callout)
        static let bodyBold:    Font = .system(.callout, weight: .semibold)
        static let caption:     Font = .system(.footnote)
        static let captionBold: Font = .system(.footnote, weight: .semibold)
        /// Numeric values: proportional face with tabular digits (identifiers
        /// such as VINs stay readable without switching to a mono face).
        static let monoValue:   Font = .system(.callout, weight: .semibold).monospacedDigit()

        /// The stamped plate digits: heavy, rounded, tabular.
        static let plate:       Font = .system(size: 30, weight: .heavy,
                                                design: .rounded).monospacedDigit()
        /// Large figures in fact tiles and status rows.
        static let figure:      Font = .system(.title3, design: .rounded, weight: .bold)
                                            .monospacedDigit()
    }
}

// MARK: - Shadow helper
extension View {
    /// Shadow for physical objects only (the plate, floating notices).
    /// Grouped surfaces sit flat on the background and take no shadow.
    func cardShadow() -> some View {
        self.shadow(color: Theme.Colors.cardShadow,
                    radius: 6, x: 0, y: 2)
    }
}

import SwiftUI

/// The blue band on the left edge of an Israeli plate. Always on the physical
/// left, whatever the layout direction.
struct PlateStrip: View {
    var width: CGFloat = 30

    var body: some View {
        VStack(spacing: 1) {
            Spacer(minLength: 0)
            Text("IL")
                .font(.system(size: width * 0.40, weight: .heavy, design: .rounded))
            if width >= 24 {
                Text("ישראל")
                    .font(.system(size: width * 0.22, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.bottom, width * 0.16)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(Theme.Colors.plateStrip)
        .accessibilityHidden(true)
    }
}

/// Plate chrome: yellow field, dark rim, blue strip. Wraps any content (static
/// digits or the live text field) so every plate in the app is the same object.
struct PlateChrome<Content: View>: View {
    var stripWidth: CGFloat = 30
    var cornerRadius: CGFloat = Theme.Radius.plate
    var rim: CGFloat = 2
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            PlateStrip(width: stripWidth)
            content()
                .frame(maxWidth: .infinity)
        }
        .environment(\.layoutDirection, .leftToRight)
        .background(Theme.Colors.plateYellow)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.Colors.plateBorder, lineWidth: rim)
        )
    }
}

/// A read-only plate showing a number in its road format (12-345-67).
struct PlateView: View {
    enum Size { case hero, compact }

    let number: String
    var size: Size = .hero

    var body: some View {
        switch size {
        case .hero:
            PlateChrome {
                Text(PlateFormat.dashed(number))
                    .font(Theme.Typography.plate)
                    .foregroundStyle(Theme.Colors.textOnPlate)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, Theme.Spacing.m)
                    .padding(.vertical, Theme.Spacing.m)
            }
            .frame(width: 250)
            .fixedSize(horizontal: false, vertical: true)
            .cardShadow()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("מספר רישוי \(number)")
        case .compact:
            PlateChrome(stripWidth: 16, cornerRadius: 6, rim: 1.5) {
                Text(PlateFormat.dashed(number))
                    .font(.system(.footnote, design: .rounded, weight: .heavy).monospacedDigit())
                    .foregroundStyle(Theme.Colors.textOnPlate)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("מספר רישוי \(number)")
        }
    }
}

/// Road formatting for plate digits. 7 digits read 12-345-67, 8 digits read
/// 123-45-678; other lengths are left as typed.
enum PlateFormat {
    static func dashed(_ digits: String) -> String {
        let d = Array(digits)
        switch d.count {
        case 7: return "\(String(d[0..<2]))-\(String(d[2..<5]))-\(String(d[5..<7]))"
        case 8: return "\(String(d[0..<3]))-\(String(d[3..<5]))-\(String(d[5..<8]))"
        default: return digits
        }
    }

    static func dashed(_ plate: Int) -> String { dashed(String(plate)) }
}

#Preview {
    VStack(spacing: 20) {
        PlateView(number: "5970065")
        PlateView(number: "77720101")
        PlateView(number: "5970065", size: .compact)
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
}

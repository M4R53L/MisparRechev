import SwiftUI

/// Horizontal 1–15 pollution-group gauge. Green at 1, red at 15.
/// The current value is highlighted with a marker. If value is nil, shows "לא ידוע".
struct PollutionScale: View {
    let value: Int?     // 1...15
    let label: String   // default "קבוצת זיהום"

    private let range: ClosedRange<Int> = 1...15

    init(value: Int?, label: String = "קבוצת זיהום") {
        self.value = value
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack {
                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                Spacer()
                Text(currentLabel)
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }

            if let v = value, range.contains(v) {
                scale(for: v)
                    .frame(height: 16)
            } else {
                Text("לא ידוע")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(currentLabel)
    }

    private var currentLabel: String {
        guard let v = value, range.contains(v) else { return "לא ידוע" }
        return "\(v) / \(range.upperBound)"
    }

    // MARK: - Subviews

    private func scale(for v: Int) -> some View {
        GeometryReader { geo in
            let count = CGFloat(range.count)
            let segmentWidth = (geo.size.width - (count - 1) * 2) / count
            HStack(spacing: 2) {
                ForEach(range, id: \.self) { i in
                    let isActive = i <= v
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(isActive ? color(for: i) : Theme.Colors.divider.opacity(0.5))
                        .frame(width: max(segmentWidth, 4), height: 12)
                }
            }
            .overlay(alignment: .top) {
                if let v = value {
                    Triangle()
                        .fill(Theme.Colors.textPrimary)
                        .frame(width: 10, height: 6)
                        .offset(x: markerOffset(for: v, in: geo.size.width),
                                y: -7)
                }
            }
        }
    }

    private func markerOffset(for v: Int, in total: CGFloat) -> CGFloat {
        let count = CGFloat(range.count)
        let segmentWidth = (total - (count - 1) * 2) / count
        // The first segment in RTL sits at the right (leading).
        // We place the marker at the center of segment index (v-1).
        let indexFromLeading = CGFloat(v - range.lowerBound)
        let xFromLeading = indexFromLeading * (segmentWidth + 2) + segmentWidth / 2
        // Convert from leading (right) to view x (left) by negating and centering.
        return (xFromLeading - total / 2)
    }

    private func color(for i: Int) -> Color {
        // Smooth hue from green (1) to red (15).
        let t = Double(i - range.lowerBound) /
                Double(range.upperBound - range.lowerBound)   // 0...1
        // Hue: 0.33 (green) → 0.0 (red).
        let hue = 0.33 * (1 - t)
        return Color(hue: hue, saturation: 0.70, brightness: 0.88)
    }
}

/// Small downward-pointing triangle used as a marker.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    VStack(spacing: 24) {
        PollutionScale(value: 1)
        PollutionScale(value: 8)
        PollutionScale(value: 15)
        PollutionScale(value: nil)
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

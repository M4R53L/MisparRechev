import SwiftUI

/// Horizontal 1–15 pollution-group gauge. Green at 1, red at 15.
/// The current value is highlighted with a marker. If value is nil, shows "לא ידוע".
struct PollutionScale: View {
    let value: Int?     // 1...15
    let label: String   // default "קבוצת זיהום"

    init(value: Int?, label: String = "קבוצת זיהום") {
        self.value = value
        self.label = label
    }

    var body: some View {
        SegmentedScale(value: value, range: 1...15, label: label) { t in
            // Hue: 0.33 (green) at the low end → 0.0 (red) at the high end.
            Color(hue: 0.33 * (1 - t), saturation: 0.70, brightness: 0.88)
        }
    }
}

/// Horizontal 0–8 safety-equipment-level gauge (רמת אבזור בטיחותי).
/// The inverse of the pollution scale: red at 0, green at 8.
struct SafetyEquipmentScale: View {
    let value: Int?     // 0...8
    let label: String   // default "רמת אבזור בטיחותי"

    init(value: Int?, label: String = "רמת אבזור בטיחותי") {
        self.value = value
        self.label = label
    }

    var body: some View {
        SegmentedScale(value: value, range: 0...8, label: label) { t in
            // Hue: 0.0 (red) at the low end → 0.33 (green) at the high end.
            Color(hue: 0.33 * t, saturation: 0.70, brightness: 0.88)
        }
    }
}

/// Shared horizontal segmented gauge: one colored segment per value in
/// `range`, filled up to the current value, with a marker above it. The
/// color closure receives the segment's normalized position `t` (0...1).
struct SegmentedScale: View {
    let value: Int?
    let range: ClosedRange<Int>
    let label: String
    let color: (Double) -> Color

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

    /// Normalized position of a value within the range (0...1).
    private func t(for i: Int) -> Double {
        Double(i - range.lowerBound) / Double(max(range.upperBound - range.lowerBound, 1))
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
                        .fill(isActive ? color(t(for: i)) : Theme.Colors.divider.opacity(0.5))
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
        // We place the marker at the center of segment index (v - lowerBound).
        let indexFromLeading = CGFloat(v - range.lowerBound)
        let xFromLeading = indexFromLeading * (segmentWidth + 2) + segmentWidth / 2
        // Convert from leading (right) to view x (left) by negating and centering.
        return (xFromLeading - total / 2)
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
        Divider()
        SafetyEquipmentScale(value: 0)
        SafetyEquipmentScale(value: 2)
        SafetyEquipmentScale(value: 8)
        SafetyEquipmentScale(value: nil)
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

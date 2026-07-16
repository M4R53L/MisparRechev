import SwiftUI

// MARK: - Shimmer modifier

/// A subtle moving highlight overlay used as a "loading" effect on a card or row.
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1
    var duration: Double = Theme.Motion.shimmerDuration

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .white.opacity(0.0),
                            .white.opacity(0.55),
                            .white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 1.6)
                    .offset(x: phase * geo.size.width * 1.8)
                    .blendMode(.plusLighter)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .accessibilityHidden(true)
    }
}

extension View {
    /// Apply a shimmering overlay to this view.
    func shimmering() -> some View { modifier(ShimmerModifier()) }
}

// MARK: - Skeleton primitives

/// A rounded grey rectangle that shimmers.
struct SkeletonBox: View {
    var height: CGFloat = 16
    var cornerRadius: CGFloat = Theme.Radius.small

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Theme.Colors.divider.opacity(0.35))
            .frame(height: height)
            .shimmering()
    }
}

/// A skeleton row that mimics `InfoRow`: a short label-box on the leading side
/// and a longer value-box on the trailing side.
struct SkeletonInfoRow: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            SkeletonBox(height: 12)
                .frame(width: 90, alignment: .leading)
            Spacer(minLength: Theme.Spacing.s)
            SkeletonBox(height: 14)
                .frame(width: 140, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }
}

/// A skeleton card: a title and several rows.
struct SkeletonCard: View {
    var rowCount: Int = 3
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            SkeletonBox(height: 18)
                .frame(maxWidth: 160, alignment: .leading)
            ForEach(0..<rowCount, id: \.self) { _ in
                SkeletonInfoRow()
            }
        }
        .padding(Theme.Spacing.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Colors.surface)
        )
        .cardShadow()
    }
}

#Preview {
    VStack(spacing: 16) {
        SkeletonCard(rowCount: 3)
        SkeletonCard(rowCount: 4)
    }
    .padding()
    .background(Theme.Colors.background)
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.locale, Locale(identifier: "he_IL"))
}

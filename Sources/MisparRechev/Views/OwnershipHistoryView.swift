import SwiftUI

/// Ownership-transfer timeline (פרטי / סוחר / ליסינג / חברה …) with date
/// ranges, plus reported change flags. Shown inside the "היסטוריה ובעלות" card.
struct OwnershipHistoryView: View {
    let ownership: [OwnershipRecord]
    let vehicle: Vehicle
    let mileage: VehicleHistory?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if !ownership.isEmpty {
                Text("היסטוריית בעלות, \(ownership.count) רשומות")
                    .font(Theme.Typography.captionBold)
                    .foregroundStyle(Theme.Colors.textSecondary)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(ownership.enumerated()), id: \.offset) { idx, rec in
                        let isLast = idx == ownership.count - 1
                        ownershipRow(rec,
                                     endDate: isLast ? nil : ownership[idx + 1].baalut_dt,
                                     isLast: isLast)
                    }
                }
            }

            if let m = mileage, !m.changeLabels.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("שינויים שדווחו")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                    FlowLayout(spacing: 6) {
                        ForEach(m.changeLabels, id: \.self) { label in
                            WarningChip(text: label)
                        }
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
    }

    // MARK: - Timeline row

    @ViewBuilder
    private func ownershipRow(_ rec: OwnershipRecord, endDate: Int?, isLast: Bool) -> some View {
        let start = SearchViewModel.displayMonthYear(rec.baalut_dt) ?? "—"
        let rangeText: String = {
            if isLast { return "מ\(start), בעלים נוכחי" }
            let end = SearchViewModel.displayMonthYear(endDate) ?? "—"
            return "מ\(start) עד \(end)"
        }()

        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            // Marker + connecting line (timeline spine).
            VStack(spacing: 0) {
                Circle()
                    .fill(isLast ? Theme.Colors.primary : Theme.Colors.neutral)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(Theme.Colors.divider)
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(rec.ownerType ?? "—")
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                Text(rangeText)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }
            .padding(.bottom, Theme.Spacing.m)

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rec.ownerType ?? "בעלות") — \(rangeText)")
    }
}

// MARK: - Warning chip (reported changes)

private struct WarningChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(Theme.Typography.captionBold)
        }
        .foregroundStyle(Theme.Colors.textOnPrimary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.Colors.warning))
        .accessibilityLabel("שינוי שדווח: \(text)")
    }
}

// MARK: - Simple flow layout (iOS 16 compatible)

/// A minimal flow layout that wraps subviews to the next line when they overflow.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let result = layout(subviews: subviews, in: maxWidth)
        let contentWidth = result.frames.map { $0.maxX }.max() ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : contentWidth,
                      height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, in: bounds.width)
        for (idx, frame) in result.frames.enumerated() {
            subviews[idx].place(at: CGPoint(x: bounds.minX + frame.minX,
                                            y: bounds.minY + frame.minY),
                                proposal: ProposedViewSize(frame.size))
        }
    }

    private func layout(subviews: Subviews, in maxWidth: CGFloat) -> (frames: [CGRect], height: CGFloat) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        let containerWidth = maxWidth.isFinite ? maxWidth : 320
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > containerWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (frames, y + rowHeight)
    }
}

#Preview {
    let ownership: [OwnershipRecord] = [
        .init(mispar_rechev: 3256880, baalut_dt: 201703, baalut: "פרטי"),
        .init(mispar_rechev: 3256880, baalut_dt: 202105, baalut: "סוחר"),
        .init(mispar_rechev: 3256880, baalut_dt: 202106, baalut: "פרטי")
    ]
    return OwnershipHistoryView(ownership: ownership, vehicle: .preview, mileage: .preview)
        .padding()
        .background(Theme.Colors.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}
import SwiftUI

// MARK: - Row builder (pure, unit-testable)

/// Builds the label/value rows of the side-by-side comparison table.
/// Values are display-ready strings; `nil` renders as "—" so the two columns
/// stay aligned. Presentation is neutral — no "winner" highlighting.
enum CompareMetrics {
    struct Row: Identifiable, Equatable {
        let label: String
        /// Side A (the right column under RTL).
        let a: String?
        let b: String?
        var id: String { label }
    }

    static func rows(a: LookupResult?, b: LookupResult?) -> [Row] {
        func make(_ label: String, _ value: (LookupResult) -> String?) -> Row {
            Row(label: label, a: a.flatMap(value), b: b.flatMap(value))
        }
        // Built with appends (not one array literal) to keep type-checking fast.
        var rows: [Row] = []
        rows.append(make("שנת ייצור") { $0.vehicle.year })
        rows.append(make("הספק (כ״ס)") { $0.spec?.horsepower.map(String.init) })
        rows.append(make("תיבת הילוכים") { $0.spec?.gearbox })
        rows.append(make("הנעה") { $0.spec?.driveType })
        rows.append(make("קילומטראז׳") { $0.mileage?.mileageKm })
        rows.append(make("רשומות בעלות") { $0.ownership.isEmpty ? nil : String($0.ownership.count) })
        rows.append(make("ריקולים פתוחים") { String($0.recalls.count) })
        rows.append(make("רמת אבזור בטיחותי") { result in
            (result.vehicle.ramat_eivzur_betihuty ?? result.spec?.safetyEquipmentLevel)
                .map { "\($0) / 8" }
        })
        rows.append(make("קבוצת זיהום") { $0.vehicle.kvutzat_zihum.map { "\($0) / 15" } })
        rows.append(make("כריות אוויר") { $0.spec?.airbagCount.map(String.init) })
        rows.append(make("פליטת CO2") { $0.spec?.co2Display })
        rows.append(make("מחיר מחירון כחדש") { result in
            let amounts = result.prices.compactMap(\.mehir).filter { $0 > 0 }
            guard let min = amounts.min(), let max = amounts.max() else { return nil }
            return min == max
                ? PriceEstimator.formatted(min)
                : "\(PriceEstimator.formatted(min))–\(PriceEstimator.formatted(max))"
        })
        rows.append(make("שווי מוערך") { result in
            guard result.prices.count == 1,
                  let newPrice = result.prices.first?.mehir,
                  let year = result.vehicle.shnat_yitzur,
                  let estimate = PriceEstimator.estimatedValue(newPrice: newPrice,
                                                              productionYear: year)
            else { return nil }
            return PriceEstimator.formatted(estimate)
        })
        return rows
    }
}

// MARK: - Compare screen

/// Side-by-side comparison of two plates. Each side loads from the offline
/// snapshot when available (instant, works offline), else fetches live.
struct CompareView: View {
    let plateA: Int
    let plateB: Int
    /// Pre-supplied result for side A (when entered from an open report).
    let initialA: LookupResult?

    enum SideState: Equatable {
        case loading
        case loaded(LookupResult)
        case failed

        var result: LookupResult? {
            if case .loaded(let result) = self { return result }
            return nil
        }
    }

    private enum Side { case a, b }

    @State private var sideA: SideState = .loading
    @State private var sideB: SideState = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("השוואת רכבים")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                header
                comparisonCard

                Text("ההשוואה מבוססת על נתוני משרד התחבורה והערכות מקורבות בלבד")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .task { await loadSides() }
    }

    // MARK: - Header (plate chips + per-side status)

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m) {
            sideHeader(plate: plateA, state: sideA, side: .a)
            sideHeader(plate: plateB, state: sideB, side: .b)
        }
    }

    @ViewBuilder
    private func sideHeader(plate: Int, state: SideState, side: Side) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(String(plate))
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.Colors.textOnPlate)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .fill(Theme.Colors.plateYellow)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .strokeBorder(Theme.Colors.plateBorder, lineWidth: 1.5)
                )

            switch state {
            case .loading:
                ProgressView()
                    .padding(.top, Theme.Spacing.xs)
            case .loaded(let result):
                Text(result.vehicle.displayName)
                    .font(Theme.Typography.captionBold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            case .failed:
                VStack(spacing: Theme.Spacing.xs) {
                    Text("לא ניתן לטעון")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.danger)
                    Button("נסה שוב") {
                        retry(side)
                    }
                    .font(Theme.Typography.captionBold)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Comparison table

    private var comparisonCard: some View {
        let rows = CompareMetrics.rows(a: sideA.result, b: sideB.result)
        return Grid(horizontalSpacing: Theme.Spacing.s, verticalSpacing: 0) {
            ForEach(rows) { row in
                GridRow {
                    valueCell(row.a)
                    Text(row.label)
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    valueCell(row.b)
                }
                .padding(.vertical, Theme.Spacing.s)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.label): \(row.a ?? "אין נתון") מול \(row.b ?? "אין נתון")")
                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
        .padding(Theme.Spacing.m)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .fill(Theme.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                .strokeBorder(Theme.Colors.divider.opacity(0.5), lineWidth: 0.5)
        )
        .cardShadow()
    }

    private func valueCell(_ text: String?) -> some View {
        Text(text ?? "—")
            .font(Theme.Typography.captionBold)
            .monospacedDigit()
            .foregroundStyle(text == nil ? Theme.Colors.textTertiary
                                         : Theme.Colors.textPrimary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Loading

    private func loadSides() async {
        if let initialA, sideA == .loading {
            sideA = .loaded(initialA)
        }
        await withTaskGroup(of: Void.self) { group in
            if sideA.result == nil {
                group.addTask { await load(plate: plateA, side: .a) }
            }
            if sideB.result == nil {
                group.addTask { await load(plate: plateB, side: .b) }
            }
        }
    }

    private func retry(_ side: Side) {
        set(side, .loading)
        let plate = side == .a ? plateA : plateB
        Task { await load(plate: plate, side: side) }
    }

    /// Snapshot-first (instant, offline-friendly); live fetch as fallback,
    /// persisting the fresh result back into the snapshot store.
    private func load(plate: Int, side: Side) async {
        if let snap = SnapshotStore.load().snapshot(for: plate) {
            set(side, .loaded(snap.result))
            return
        }
        do {
            let result = try await VehicleService().lookup(plate: plate)
            SnapshotStore.load().saving(result, for: plate).save()
            set(side, .loaded(result))
        } catch {
            set(side, .failed)
        }
    }

    private func set(_ side: Side, _ state: SideState) {
        switch side {
        case .a: sideA = state
        case .b: sideB = state
        }
    }
}

// MARK: - Entry from an open report

/// Sheet flow when comparing starts from an open result: pick the other
/// vehicle from the search history, then show the comparison.
struct CompareFromResultSheet: View {
    let currentPlate: Int
    let currentResult: LookupResult
    let history: [SearchHistoryStore.Entry]

    @State private var otherPlate: Int?

    private var candidates: [SearchHistoryStore.Entry] {
        history.filter { $0.plate != currentPlate }
    }

    var body: some View {
        if let otherPlate {
            CompareView(plateA: currentPlate, plateB: otherPlate,
                        initialA: currentResult)
        } else {
            picker
        }
    }

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                Text("בחרו רכב להשוואה")
                    .font(Theme.Typography.title)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .center)

                if candidates.isEmpty {
                    Text("חפשו רכב נוסף כדי להשוות אליו")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, Theme.Spacing.xl)
                } else {
                    VStack(spacing: 0) {
                        ForEach(candidates) { entry in
                            Button {
                                otherPlate = entry.plate
                            } label: {
                                HStack(spacing: Theme.Spacing.m) {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(Theme.Colors.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        if let title = entry.title {
                                            Text(title)
                                                .font(Theme.Typography.bodyBold)
                                                .foregroundStyle(Theme.Colors.textPrimary)
                                        }
                                        Text(String(entry.plate))
                                            .font(Theme.Typography.monoValue)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                    Spacer()
                                }
                                .padding(Theme.Spacing.m)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            if entry.id != candidates.last?.id {
                                Divider().padding(.leading, Theme.Spacing.l)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                            .fill(Theme.Colors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                            .strokeBorder(Theme.Colors.divider.opacity(0.5), lineWidth: 0.5)
                    )
                    .cardShadow()
                }
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}

#Preview("Compare") {
    CompareView(plateA: 5970065, plateB: 77720101, initialA: nil)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

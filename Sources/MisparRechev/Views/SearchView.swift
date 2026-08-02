import SwiftUI
import VisionKit

/// The hero / empty state. Title, plate field, search button, and a recent-history list.
/// Two plates picked for comparison; `Identifiable` so it can drive a sheet.
private struct ComparePair: Identifiable, Equatable {
    let a: Int
    let b: Int
    var id: String { "\(a)-\(b)" }
}

struct SearchView: View {
    @Bindable var viewModel: SearchViewModel
    @State private var isShowingScanner = false
    @State private var isCompareMode = false
    @State private var compareSelection: [Int] = []
    @State private var comparePair: ComparePair?

    /// Camera scanning needs a device with a camera and an A12+ Neural Engine
    /// (every iOS 17 device qualifies); false on the simulator, hiding the button.
    private var canScan: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                header
                plateAndButton
                myCarSection
                historySection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background.ignoresSafeArea())
        .sheet(isPresented: $isShowingScanner) {
            PlateScannerSheet { plate in
                isShowingScanner = false
                viewModel.searchFromScan(plate: plate)
            }
        }
        .sheet(item: $comparePair, onDismiss: {
            isCompareMode = false
            compareSelection = []
        }) { pair in
            CompareView(plateA: pair.a, plateB: pair.b, initialA: nil)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "car.2.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Theme.Colors.primary)
                    .accessibilityHidden(true)
                Text("מספר רכב")
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
            }
            Text("בדיקת פרטי רכב לפי מספר רישוי ממאגרי משרד התחבורה")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Plate + search button

    private var plateAndButton: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            PlateField(text: $viewModel.plateInput,
                       onScan: canScan ? { isShowingScanner = true } : nil)

            if viewModel.scanOfflineNotice {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("אין חיבור לאינטרנט — המספר שנסרק הוזן בשדה")
                        .font(Theme.Typography.caption)
                }
                .foregroundStyle(Theme.Colors.textSecondary)
            }

            Button {
                viewModel.search()
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    Image(systemName: "magnifyingglass")
                    Text("חיפוש")
                }
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textOnPrimary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                        .fill(viewModel.canSearch ? Theme.Colors.primary
                                                  : Theme.Colors.neutral)
                )
            }
            .disabled(!viewModel.canSearch)
            .accessibilityHint("מבצע חיפוש לפי מספר הרישוי שהוזן")
        }
    }

    // MARK: - My car

    @ViewBuilder
    private var myCarSection: some View {
        if let car = viewModel.myCar.car {
            MyCarCard(car: car) {
                viewModel.searchFromHistory(plate: car.plate)
            }
        }
    }

    // MARK: - History

    @ViewBuilder
    private var historySection: some View {
        if !viewModel.history.entries.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text("חיפושים אחרונים")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    if viewModel.history.entries.count >= 2 {
                        Button {
                            isCompareMode.toggle()
                            compareSelection = []
                        } label: {
                            Text(isCompareMode ? "ביטול" : "השווה")
                                .font(Theme.Typography.captionBold)
                        }
                    }
                    if !isCompareMode {
                        Button(role: .destructive) {
                            viewModel.clearHistory()
                        } label: {
                            Text("נקה היסטוריה")
                                .font(Theme.Typography.captionBold)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.xs)

                if isCompareMode {
                    Text("בחרו שני רכבים להשוואה")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Colors.textSecondary)
                        .padding(.bottom, Theme.Spacing.xs)
                }

                VStack(spacing: 0) {
                    ForEach(viewModel.history.entries) { entry in
                        Button {
                            if isCompareMode {
                                toggleCompareSelection(entry.plate)
                            } else {
                                viewModel.searchFromHistory(plate: entry.plate)
                            }
                        } label: {
                            HStack(spacing: Theme.Spacing.m) {
                                Image(systemName: isCompareMode
                                      ? (compareSelection.contains(entry.plate)
                                         ? "checkmark.circle.fill" : "circle")
                                      : "clock.arrow.circlepath")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Theme.Colors.primary)
                                if let title = entry.title {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(title)
                                            .font(Theme.Typography.bodyBold)
                                            .foregroundStyle(Theme.Colors.textPrimary)
                                        Text(format(plate: entry.plate))
                                            .font(Theme.Typography.monoValue)
                                            .foregroundStyle(Theme.Colors.textSecondary)
                                    }
                                } else {
                                    Text(format(plate: entry.plate))
                                        .font(Theme.Typography.monoValue)
                                        .foregroundStyle(Theme.Colors.textPrimary)
                                }
                                Spacer()
                                Text(relativeTime(entry.timestamp))
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.textSecondary)
                            }
                            .padding(.vertical, Theme.Spacing.m)
                            .padding(.horizontal, Theme.Spacing.m)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {   // trailing = right in LTR; SwiftUI mirrors for RTL
                            Button(role: .destructive) {
                                viewModel.removeHistory(plate: entry.plate)
                            } label: { Label("מחק", systemImage: "trash") }
                        }
                        if entry.id != viewModel.history.entries.last?.id {
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
    }

    // MARK: - Helpers

    /// Toggles a plate in the compare selection; picking the second one opens
    /// the comparison sheet.
    private func toggleCompareSelection(_ plate: Int) {
        if let idx = compareSelection.firstIndex(of: plate) {
            compareSelection.remove(at: idx)
        } else {
            compareSelection.append(plate)
            if compareSelection.count == 2 {
                comparePair = ComparePair(a: compareSelection[0], b: compareSelection[1])
            }
        }
    }

    private func format(plate: Int) -> String { String(plate) }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    SearchView(viewModel: SearchViewModel())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

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
    @State private var isShowingSettings = false
    @State private var isConfirmingClear = false
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
                plateAndButton
                myCarSection
                historySection
            }
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.top, Theme.Spacing.s)
            .padding(.bottom, Theme.Spacing.xxl)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("מספר רכב")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("הגדרות ועזרה")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("חיפוש") { viewModel.search() }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.canSearch)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(viewModel: viewModel)
        }
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
        .confirmationDialog("למחוק את כל החיפושים האחרונים?",
                            isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("מחיקת ההיסטוריה", role: .destructive) { viewModel.clearHistory() }
            Button("ביטול", role: .cancel) {}
        }
    }

    // MARK: - Plate + search button

    private var plateAndButton: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text("הקלידו מספר רישוי וקבלו את פרטי הרכב ממאגרי משרד התחבורה")
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            PlateField(text: $viewModel.plateInput)

            if viewModel.scanOfflineNotice {
                Label("אין חיבור לאינטרנט. המספר שנסרק הוזן בשדה.", systemImage: "wifi.slash")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
            }

            HStack(spacing: Theme.Spacing.m) {
                Button {
                    viewModel.search()
                } label: {
                    Label("חיפוש", systemImage: "magnifyingglass")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!viewModel.canSearch)
                .accessibilityLabel("חיפוש")
                .accessibilityHint("מבצע חיפוש לפי מספר הרישוי שהוזן")

                if canScan {
                    Button {
                        isShowingScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(.title3, weight: .semibold))
                            .frame(width: 52, height: 52)
                            .foregroundStyle(Theme.Colors.primary)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                                    .fill(Theme.Colors.primary.opacity(0.12))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("סריקת לוחית רישוי במצלמה")
                }
            }
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
        if viewModel.history.entries.isEmpty {
            emptyHistory
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                HStack {
                    Text(isCompareMode ? "בחרו שני רכבים להשוואה" : "חיפושים אחרונים")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.textPrimary)
                    Spacer()
                    if isCompareMode {
                        Button("ביטול") {
                            isCompareMode = false
                            compareSelection = []
                        }
                        .font(Theme.Typography.bodyBold)
                    } else {
                        Menu {
                            if viewModel.history.entries.count >= 2 {
                                Button {
                                    isCompareMode = true
                                    compareSelection = []
                                } label: {
                                    Label("השוואה בין שני רכבים", systemImage: "arrow.left.arrow.right")
                                }
                            }
                            Button(role: .destructive) {
                                isConfirmingClear = true
                            } label: {
                                Label("מחיקת ההיסטוריה", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(.title3))
                                .frame(width: 44, height: 32, alignment: .trailing)
                        }
                        .accessibilityLabel("אפשרויות היסטוריה")
                    }
                }
                .padding(.horizontal, Theme.Spacing.xs)

                VStack(spacing: 0) {
                    ForEach(viewModel.history.entries) { entry in
                        Button {
                            if isCompareMode {
                                toggleCompareSelection(entry.plate)
                            } else {
                                viewModel.searchFromHistory(plate: entry.plate)
                            }
                        } label: {
                            historyRow(entry)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                viewModel.removeHistory(plate: entry.plate)
                            } label: { Label("מחיקה", systemImage: "trash") }
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
            }
        }
    }

    private func historyRow(_ entry: SearchHistoryStore.Entry) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            if isCompareMode {
                Image(systemName: compareSelection.contains(entry.plate)
                      ? "checkmark.circle.fill" : "circle")
                    .font(.system(.title3))
                    .foregroundStyle(Theme.Colors.primary)
            } else {
                BrandLogo(brand: CarBrands.brand(forManufacturer: entry.manufacturer),
                          fallbackName: entry.manufacturer ?? "#", size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.model ?? entry.manufacturer ?? PlateFormat.dashed(entry.plate))
                    .font(Theme.Typography.bodyBold)
                    .foregroundStyle(Theme.Colors.textPrimary)
                    .lineLimit(1)
                Text([entry.year, relativeTime(entry.timestamp)].compactMap { $0 }
                        .joined(separator: ", "))
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: Theme.Spacing.s)
            PlateView(number: String(entry.plate), size: .compact)
        }
        .padding(.vertical, Theme.Spacing.m)
        .padding(.horizontal, Theme.Spacing.l)
        .contentShape(Rectangle())
    }

    /// First-run state of the list: says what will appear here and how.
    private var emptyHistory: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("מה תמצאו בדוח")
                .font(Theme.Typography.headline)
                .foregroundStyle(Theme.Colors.textPrimary)
                .padding(.horizontal, Theme.Spacing.xs)

            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                ForEach(ReportHighlight.all) { item in
                    HStack(alignment: .top, spacing: Theme.Spacing.m) {
                        Image(systemName: item.systemImage)
                            .font(.system(.body, weight: .semibold))
                            .foregroundStyle(Theme.Colors.primary)
                            .frame(width: 28)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(Theme.Typography.bodyBold)
                                .foregroundStyle(Theme.Colors.textPrimary)
                            Text(item.detail)
                                .font(Theme.Typography.caption)
                                .foregroundStyle(Theme.Colors.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Colors.surface)
            )
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

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "he_IL")
        f.unitsStyle = .full
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// What a report contains. Shared by the empty search screen and onboarding
/// so both describe the product in the same words.
struct ReportHighlight: Identifiable {
    let systemImage: String
    let title: String
    let detail: String
    var id: String { title }

    static let all: [ReportHighlight] = [
        .init(systemImage: "checkmark.seal.fill", title: "טסט ורישוי",
              detail: "עד מתי הטסט בתוקף ומתי הרכב עלה לכביש"),
        .init(systemImage: "exclamationmark.triangle.fill", title: "ריקולים פתוחים",
              detail: "קריאות תיקון של היצרן שעדיין לא בוצעו"),
        .init(systemImage: "person.2.fill", title: "בעלויות וקילומטראז׳",
              detail: "מי החזיק ברכב, ממתי, וכמה ק״מ נרשמו בטסט האחרון"),
        .init(systemImage: "shekelsign.circle.fill", title: "מחירון ומפרט",
              detail: "מחיר הרכב כחדש, רמת גימור, הספק ומערכות בטיחות")
    ]
}

#Preview {
    SearchView(viewModel: SearchViewModel())
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

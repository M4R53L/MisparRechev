import SwiftUI

/// "מחירון" card: official importer list price for the model as new, a rough
/// current-value estimate (clearly disclaimed) that the user can overwrite with
/// a real valuation, the importer name, and a link out to Levi Yitzhak for an
/// authoritative used-car valuation.
struct PriceView: View {
    let prices: [NewCarPrice]
    let vehicle: Vehicle
    /// Manually entered current value (persisted by the caller). `nil` → show
    /// the automatic depreciation estimate.
    @Binding var manualValue: Int?

    @State private var isEditing = false
    @State private var draft = ""

    var body: some View {
        InfoCard(title: "מחירון", systemImage: "shekelsign.circle.fill") {
            if let value = displayedValue {
                InfoRow(label: manualValue == nil ? "שווי מוערך כיום" : "שווי מעודכן (הוזן ידנית)",
                        value: PriceEstimator.formatted(value),
                        monospaced: true)
                Text(manualValue == nil
                     ? "הערכה גסה לפי פחת ממוצע בלבד. אינה תחליף למחירון מקצועי"
                     : "הוזן ידנית על־פי מחירון חיצוני. מופיע גם בשיתוף ובדוח ה־PDF")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            editControls

            if prices.count == 1, let importer = prices.first?.importer {
                InfoRow(label: "יבואן", value: importer)
            }

            leviYitzhakLink
                .padding(.top, Theme.Spacing.s)
        }
        .alert("עדכון שווי הרכב", isPresented: $isEditing) {
            TextField("שווי בשקלים", text: $draft)
                .keyboardType(.numberPad)
            Button("שמירה") { commitDraft() }
            Button("ביטול", role: .cancel) {}
        } message: {
            Text("הזן את השווי שמצאת במחירון (לוי יצחק). השווי יישמר לרכב זה ויופיע בדוח ה־PDF ובשיתוף.")
        }
    }

    // MARK: - Editing

    private var editControls: some View {
        HStack(spacing: Theme.Spacing.l) {
            Button {
                draft = displayedValue.map(String.init) ?? ""
                isEditing = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                    Text(displayedValue == nil ? "הזנת שווי מהמחירון" : "עריכת השווי")
                }
            }
            .accessibilityLabel("עריכת שווי הרכב")

            if manualValue != nil {
                Button {
                    manualValue = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("חזרה לאומדן")
                    }
                }
                .accessibilityLabel("איפוס לאומדן האוטומטי")
            }

            Spacer(minLength: 0)
        }
        .font(Theme.Typography.captionBold)
        .foregroundStyle(Theme.Colors.primary)
        .padding(.top, 2)
    }

    /// Digits only — Hebrew keyboards and pasted text may bring separators.
    private func commitDraft() {
        let digits = draft.filter(\.isNumber)
        manualValue = Int(digits).flatMap { $0 > 0 ? $0 : nil }
    }

    // MARK: - Values

    /// The manual value when set, else the automatic estimate.
    private var displayedValue: Int? {
        manualValue ?? estimatedValue
    }

    /// Estimate only for the unambiguous single-record case.
    private var estimatedValue: Int? {
        guard prices.count == 1,
              let newPrice = prices.first?.mehir,
              let year = vehicle.shnat_yitzur else { return nil }
        return PriceEstimator.estimatedValue(newPrice: newPrice, productionYear: year)
    }

    // MARK: - Levi Yitzhak link

    /// The Levi Yitzhak app has no universal links or published URL scheme
    /// (verified), so deep-linking straight into it isn't possible. Its App
    /// Store page is the reliable route: opens in the App Store app, which
    /// shows "פתח" when the app is installed and installs it otherwise.
    private static let leviYitzhakAppURL =
        URL(string: "https://apps.apple.com/il/app/id1478184705")!

    private var leviYitzhakLink: some View {
        Link(destination: Self.leviYitzhakAppURL) {
            HStack(spacing: Theme.Spacing.s) {
                Image(systemName: "arrow.up.forward.app")
                Text("בדיקת שווי מדויק במחירון לוי יצחק")
            }
            .font(Theme.Typography.captionBold)
            .foregroundStyle(Theme.Colors.primary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Theme.Colors.primary.opacity(0.12))
            )
        }
        .accessibilityLabel("פתיחת אפליקציית מחירון לוי יצחק")
    }
}

#Preview {
    @Previewable @State var manualValue: Int? = nil
    PriceView(prices: [.preview], vehicle: .preview, manualValue: $manualValue)
        .padding()
        .background(Theme.Colors.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

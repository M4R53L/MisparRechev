import SwiftUI

/// "מחירון" card: official importer list price for the model as new, a rough
/// current-value estimate (clearly disclaimed), the importer name, and a link
/// out to Levi Yitzhak for an authoritative used-car valuation.
struct PriceView: View {
    let prices: [NewCarPrice]
    let vehicle: Vehicle

    var body: some View {
        InfoCard(title: "מחירון", systemImage: "shekelsign.circle.fill") {
            InfoRow(label: newPriceLabel, value: newPriceText, monospaced: true)

            if let estimate = estimatedValue {
                InfoRow(label: "שווי מוערך כיום",
                        value: PriceEstimator.formatted(estimate),
                        monospaced: true)
                Text("הערכה גסה לפי פחת ממוצע בלבד — אינה תחליף למחירון מקצועי")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.textTertiary)
            }

            if prices.count == 1, let importer = prices.first?.importer {
                InfoRow(label: "יבואן", value: importer)
            }

            leviYitzhakLink
                .padding(.top, Theme.Spacing.s)
        }
    }

    // MARK: - Values

    private var newPriceLabel: String {
        if let year = vehicle.year { return "מחיר מחירון כחדש (\(year))" }
        return "מחיר מחירון כחדש"
    }

    /// Single record → its price; multiple → "min–max" range.
    private var newPriceText: String? {
        let amounts = prices.compactMap(\.mehir).filter { $0 > 0 }
        guard let min = amounts.min(), let max = amounts.max() else { return nil }
        return min == max
            ? PriceEstimator.formatted(min)
            : "\(PriceEstimator.formatted(min))–\(PriceEstimator.formatted(max))"
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
                Text("בדיקת שווי מדויק — מחירון לוי יצחק")
            }
            .font(Theme.Typography.captionBold)
            .foregroundStyle(Theme.Colors.primary)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(Theme.Colors.primary, lineWidth: 1)
            )
        }
        .accessibilityLabel("פתיחת אפליקציית מחירון לוי יצחק")
    }
}

#Preview {
    PriceView(prices: [.preview], vehicle: .preview)
        .padding()
        .background(Theme.Colors.background)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "he_IL"))
}

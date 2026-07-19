import Foundation

/// Rough current-value estimation from a new-car list price. Deliberately
/// crude — an average depreciation curve, not a professional valuation — and
/// always presented in the UI with a disclaimer.
enum PriceEstimator {
    /// −15% for the first year, −10% per additional year, floored at 5% of the
    /// new price, rounded to the nearest ₪500.
    ///
    /// Returns `nil` for current-year (or future-year) cars, where the list
    /// price itself is the better number. `now` is injectable for tests.
    static func estimatedValue(newPrice: Int, productionYear: Int, now: Date = .now) -> Int? {
        guard newPrice > 0 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem") ?? .current
        let age = calendar.component(.year, from: now) - productionYear
        guard age > 0 else { return nil }

        let value = Double(newPrice) * 0.85 * pow(0.90, Double(age - 1))
        let floored = max(value, Double(newPrice) * 0.05)
        return Int((floored / 500).rounded() * 500)
    }

    /// "375,900 ₪" — decimal-grouped shekel amount for display and share text.
    static func formatted(_ shekels: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "he_IL")
        let number = formatter.string(from: NSNumber(value: shekels)) ?? String(shekels)
        return "\(number) ₪"
    }
}

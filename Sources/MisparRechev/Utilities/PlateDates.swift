import Foundation

/// Whether a date-based validity (test/license) is active, expiring soon, or
/// expired. Used by the design system to pick a status color.
enum ValidityStatus: Equatable {
    case valid, expiringSoon, expired, unknown
}

/// Date parsing/formatting/validity for the registry's date strings.
///
/// Foundation-only on purpose: this file is compiled into the widget
/// extension target too (alongside `MyCarStore`), so it must not reference
/// SwiftUI, the view model, or the model layer.
enum PlateDates {
    private static let formatters: [DateFormatter] = {
        // Order matters: more specific formats first so "2017-03-16" is not
        // half-parsed by the loose "yyyy-M" format (last). Strict matching.
        let formats = ["yyyy-MM-dd'T'HH:mm:ss",
                       "yyyy-MM-dd HH:mm:ss",
                       "yyyy-MM-dd",
                       "dd/MM/yyyy",
                       "dd-MM-yyyy",
                       "yyyy-M"]
        return formats.map { fmt in
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(identifier: "Asia/Jerusalem")
            f.isLenient = false
            f.dateFormat = fmt
            return f
        }
    }()

    static func parse(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// Formats an API date string into a friendly Hebrew `d בMONTH yyyy` form.
    static func displayDate(_ dateString: String?) -> String? {
        guard let dateString, let date = parse(dateString) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "he_IL")
        formatter.timeZone = TimeZone(identifier: "Asia/Jerusalem")
        formatter.dateFormat = "d בMMMM yyyy"
        return formatter.string(from: date)
    }

    /// Computes validity status for a date string coming from the API.
    /// `now` is injectable for deterministic tests.
    static func validity(of dateString: String?, now: Date = .now) -> ValidityStatus {
        guard let dateString, let date = parse(dateString) else { return .unknown }
        let calendar = Calendar.current
        if date < calendar.startOfDay(for: now) { return .expired }
        if let soon = calendar.date(byAdding: .month, value: 2, to: now), date <= soon {
            return .expiringSoon
        }
        return .valid
    }
}

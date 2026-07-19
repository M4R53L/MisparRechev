import Foundation

/// Extracts an Israeli license-plate number from camera-recognized text.
///
/// Israeli plates are 6–8 digits, usually printed in hyphen/middle-dot-grouped
/// form ("123-45-678", "12·345·67") but sometimes recognized as one run
/// ("1234567"). Pure logic, unit-testable without a camera.
enum PlateRecognizer {
    /// Digit groups of 2–3, joined by at most one plate separator each
    /// (hyphen variants, middle dots, period, space). The lookarounds reject
    /// digits embedded in longer runs (phone numbers, VINs), and requiring
    /// group structure avoids gluing unrelated scattered digits together.
    private static let pattern =
        #"(?<![0-9])[0-9]{2,3}(?:[-–—·.• ]?[0-9]{2,3}){1,3}(?![0-9])"#

    /// Returns the digits of the first plausible plate (6–8 digits) found in
    /// the transcript, or `nil` when there is none.
    static func extractPlate(from transcript: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(transcript.startIndex..., in: transcript)
        for match in regex.matches(in: transcript, range: range) {
            guard let matchRange = Range(match.range, in: transcript) else { continue }
            let digits = transcript[matchRange].filter(\.isNumber)
            if (6...8).contains(digits.count) { return String(digits) }
        }
        return nil
    }
}

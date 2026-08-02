import Foundation

/// Extracts an Israeli license-plate number from camera-recognized text.
///
/// Israeli plates are 6–8 digits, usually printed in hyphen/middle-dot-grouped
/// form ("123-45-678", "12·345·67") but sometimes recognized as one run
/// ("1234567"). Pure logic, unit-testable without a camera.
enum PlateRecognizer {

    /// A plausible plate read: its digits and the digit-group structure as
    /// printed (e.g. "123-45-678" → groups [3, 2, 3]).
    struct Candidate: Equatable {
        let digits: String
        let groups: [Int]

        /// Matches an exact Israeli plate print format — 8 digits as 3-2-3 or
        /// 7 digits as 2-3-2. A canonical read is near-certainly a real,
        /// completely-captured plate (a truncated 8-digit read like
        /// "123-45-67" has groups 3-2-2 and fails this), so the scanner can
        /// accept it from a single frame.
        var isCanonicalFormat: Bool {
            groups == [3, 2, 3] || groups == [2, 3, 2]
        }
    }

    /// Digit groups of 2–3, joined by at most one plate separator each
    /// (hyphen variants, middle dots, period, space). The lookarounds reject
    /// digits embedded in longer runs (phone numbers, VINs), and requiring
    /// group structure avoids gluing unrelated scattered digits together.
    private static let pattern =
        #"(?<![0-9])[0-9]{2,3}(?:[-–—·.• ]?[0-9]{2,3}){1,3}(?![0-9])"#
    private static let regex = try? NSRegularExpression(pattern: pattern)

    /// All plausible plate reads (6–8 digits) in a transcript, in text order.
    static func candidates(in transcript: String) -> [Candidate] {
        guard let regex else { return [] }
        let range = NSRange(transcript.startIndex..., in: transcript)
        var found: [Candidate] = []
        for match in regex.matches(in: transcript, range: range) {
            guard let matchRange = Range(match.range, in: transcript) else { continue }
            let raw = transcript[matchRange]
            let digits = raw.filter(\.isNumber)
            guard (6...8).contains(digits.count) else { continue }
            let groups = raw.split(whereSeparator: { !$0.isNumber }).map(\.count)
            found.append(Candidate(digits: String(digits), groups: groups))
        }
        return found
    }

    /// The strongest plate read across several OCR transcripts (one per
    /// recognized text item in a camera frame): canonical print format first,
    /// then 7–8-digit reads, then legacy 6-digit reads. Ties keep text order.
    static func bestCandidate(in transcripts: [String]) -> Candidate? {
        transcripts
            .flatMap(candidates(in:))
            .max(by: { score($0) < score($1) })
    }

    private static func score(_ candidate: Candidate) -> Int {
        (candidate.isCanonicalFormat ? 4 : 0) + (candidate.digits.count >= 7 ? 1 : 0)
    }

    /// Returns the digits of the first plausible plate (6–8 digits) found in
    /// the transcript, or `nil` when there is none. Used for tap-to-accept.
    static func extractPlate(from transcript: String) -> String? {
        candidates(in: transcript).first?.digits
    }
}

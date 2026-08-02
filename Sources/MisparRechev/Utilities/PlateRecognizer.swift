import CoreGraphics
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

        /// One unbroken 7–8-digit run — cannot be a truncated longer plate
        /// and cannot be a merged stray-digit window, so it's also safe to
        /// accept fast.
        var isSingleRun: Bool {
            groups.count == 1 && digits.count >= 7
        }
    }

    /// A recognized text fragment with its on-screen geometry. VisionKit-free
    /// (plain doubles) so the logic is unit-testable without a camera — the
    /// scanner coordinator maps `RecognizedItem` bounds into these, in the
    /// scanner view's coordinate space (the same space as
    /// `PlateViewfinder`'s rects).
    struct TextObservation: Equatable {
        let transcript: String
        let minX: Double
        let maxX: Double
        let midY: Double
        let height: Double

        var midX: Double { (minX + maxX) / 2 }

        var digitCount: Int { transcript.filter(\.isNumber).count }
    }

    /// Digit groups of 2–3 joined by single "-" separators — transcripts are
    /// normalized before matching, so "-" is the only separator left. The
    /// lookarounds reject digits embedded in longer runs (phone numbers,
    /// VINs), and requiring group structure avoids gluing unrelated
    /// scattered digits together.
    private static let pattern =
        #"(?<![0-9])[0-9]{2,3}(?:-?[0-9]{2,3}){1,3}(?![0-9])"#
    private static let regex = try? NSRegularExpression(pattern: pattern)

    /// OCR renders the plate's dot separators unpredictably (·, ∙, ⋅, •, :,
    /// *, periods, odd spaces…). Collapse every run of characters that is
    /// neither a digit nor a letter into a single "-" so the plate pattern
    /// sees one uniform separator. Letters are kept as-is: a letter amid
    /// digits is usually a *misread digit*, and treating it as a separator
    /// would silently drop a digit and accept a wrong plate.
    private static func normalized(_ transcript: String) -> String {
        var result = ""
        var pendingSeparator = false
        for character in transcript {
            if character.isNumber || character.isLetter {
                if pendingSeparator {
                    result.append("-")
                    pendingSeparator = false
                }
                result.append(character)
            } else {
                pendingSeparator = true
            }
        }
        return result
    }

    /// All plausible plate reads (6–8 digits) in a transcript, in text order.
    static func candidates(in transcript: String) -> [Candidate] {
        guard let regex else { return [] }
        let text = normalized(transcript)
        let range = NSRange(text.startIndex..., in: text)
        var found: [Candidate] = []
        for match in regex.matches(in: text, range: range) {
            guard let matchRange = Range(match.range, in: text) else { continue }
            let raw = text[matchRange]
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

    /// All transcripts worth matching against, from one camera frame's text
    /// fragments.
    ///
    /// VisionKit commonly returns a plate as **several items** — one per
    /// printed digit group ("123", "45", "678") — because the groups are
    /// physically spaced apart. Each fragment alone is only 2–3 digits and
    /// can never match the plate pattern, so per-item matching alone misses
    /// most real-world reads. This rebuilds whole-plate transcripts:
    ///
    /// 1. keep only digit-bearing fragments (the "IL" strip and Hebrew text
    ///    can't be part of a plate),
    /// 2. group fragments into lines (similar vertical center),
    /// 3. sort each line left-to-right (plates read LTR regardless of the
    ///    RTL UI; the rear-camera preview is not mirrored),
    /// 4. split lines at implausibly large horizontal gaps (bumper text),
    /// 5. join every contiguous window totalling 6–8 digits with "-" — so
    ///    "123","45","678" becomes "123-45-678", groups [3,2,3], a canonical
    ///    single-frame accept. The 8-digit cap stops an unrelated digit on
    ///    the same line from poisoning a real plate read.
    ///
    /// The returned list also includes each fragment's own transcript, so
    /// single-item reads keep working exactly as before.
    static func plateTranscripts(from observations: [TextObservation]) -> [String] {
        let digitItems = observations.filter { $0.digitCount > 0 }
        var transcripts = digitItems.map(\.transcript)
        var seen = Set(transcripts)
        for line in lines(of: digitItems) {
            for segment in segments(of: line) {
                for window in windows(of: segment) {
                    let joined = window.map(\.transcript).joined(separator: "-")
                    if seen.insert(joined).inserted {
                        transcripts.append(joined)
                    }
                }
            }
        }
        return transcripts
    }

    /// Fragments on the same text line: vertical centers within 60% of the
    /// line's text height. Single pass — input is processed top-to-bottom.
    private static func lines(of items: [TextObservation]) -> [[TextObservation]] {
        var lines: [(items: [TextObservation], midYSum: Double, maxHeight: Double)] = []
        for item in items.sorted(by: { $0.midY < $1.midY }) {
            if var last = lines.last {
                let meanMidY = last.midYSum / Double(last.items.count)
                let threshold = 0.6 * max(last.maxHeight, item.height)
                if abs(item.midY - meanMidY) <= threshold {
                    last.items.append(item)
                    last.midYSum += item.midY
                    last.maxHeight = max(last.maxHeight, item.height)
                    lines[lines.count - 1] = last
                    continue
                }
            }
            lines.append((items: [item], midYSum: item.midY, maxHeight: item.height))
        }
        return lines.map(\.items)
    }

    /// A line split wherever the horizontal gap between consecutive fragments
    /// exceeds 2.5× the median fragment height — plate groups sit close
    /// together, distant text on the same line is something else.
    private static func segments(of line: [TextObservation]) -> [[TextObservation]] {
        let sorted = line.sorted(by: { $0.midX < $1.midX })
        guard let first = sorted.first else { return [] }
        let medianHeight = sorted.map(\.height).sorted()[sorted.count / 2]
        var segments: [[TextObservation]] = [[first]]
        for item in sorted.dropFirst() {
            let previous = segments[segments.count - 1].last!
            if item.minX - previous.maxX <= 2.5 * medianHeight {
                segments[segments.count - 1].append(item)
            } else {
                segments.append([item])
            }
        }
        return segments
    }

    /// Every contiguous run of fragments whose combined digit count is 6–8 —
    /// exactly the plausible plate lengths. Runs stop growing at 8 digits.
    private static func windows(of segment: [TextObservation]) -> [[TextObservation]] {
        var result: [[TextObservation]] = []
        for start in segment.indices {
            var digits = 0
            for end in start..<segment.count {
                digits += segment[end].digitCount
                if digits > 8 { break }
                if digits >= 6 {
                    result.append(Array(segment[start...end]))
                }
            }
        }
        return result
    }

    /// Fragments that can plausibly be the plate the user aimed into the
    /// cutout: digit-bearing, centered inside the acceptance region, and
    /// tall enough to be plate digits. Two height gates: an absolute floor
    /// (`PlateViewfinder.minimumTextHeightFraction` of the cutout height)
    /// and a relative one (≥ half the tallest surviving fragment) that
    /// kills dealer-frame and sticker text sharing the region.
    static func viewfinderObservations(_ observations: [TextObservation],
                                       cutout: CGRect) -> [TextObservation] {
        let region = PlateViewfinder.acceptanceRegion(for: cutout)
        let minHeight = Double(cutout.height * PlateViewfinder.minimumTextHeightFraction)
        let minY = Double(region.minY), maxY = Double(region.maxY)
        let minX = Double(region.minX), maxX = Double(region.maxX)
        let inRegion = observations.filter { item in
            guard item.digitCount > 0, item.height >= minHeight else { return false }
            guard item.midY >= minY, item.midY <= maxY else { return false }
            return item.maxX > minX && item.minX < maxX
        }
        guard let tallest = inRegion.map(\.height).max() else { return [] }
        return inRegion.filter { $0.height >= tallest * 0.5 }
    }

    /// The best plate read among fragments geometrically verified to be the
    /// aimed plate — the instant-accept path. Reuses the same line-merging
    /// and pattern rules as the transcript path.
    static func viewfinderCandidate(from observations: [TextObservation],
                                    cutout: CGRect) -> Candidate? {
        bestCandidate(in: plateTranscripts(
            from: viewfinderObservations(observations, cutout: cutout)))
    }

    /// Consecutive identical frames required before auto-accepting a read.
    /// Canonical or single-run 7–8-digit reads accept on the first frame;
    /// other 7–8-digit shapes wait one extra frame (a stray digit merged
    /// next to a 7-digit plate also totals 8); 6-digit reads wait longest —
    /// they are also what a partially captured 7–8-digit plate looks like.
    /// Reads that only passed the transcript fallback (no size/position
    /// verification) each need one extra frame.
    static func framesRequired(for candidate: Candidate, geometryVerified: Bool) -> Int {
        let base: Int
        if candidate.isCanonicalFormat || candidate.isSingleRun {
            base = 1
        } else if candidate.digits.count >= 7 {
            base = 2
        } else {
            base = 3
        }
        return geometryVerified ? base : base + 1
    }

    /// Display form of a candidate, re-grouped as printed ("123-45-678").
    static func formatted(_ candidate: Candidate) -> String {
        let digits = candidate.digits
        var parts: [String] = []
        var index = digits.startIndex
        for group in candidate.groups {
            guard index < digits.endIndex else { break }
            let end = digits.index(index, offsetBy: group, limitedBy: digits.endIndex) ?? digits.endIndex
            parts.append(String(digits[index..<end]))
            index = end
        }
        if index < digits.endIndex { parts.append(String(digits[index...])) }
        return parts.joined(separator: "-")
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

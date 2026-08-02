import XCTest
@testable import MisparRechev

/// Pure-logic tests for extracting Israeli plates from OCR transcripts —
/// no camera required, runs on the simulator.
final class PlateRecognizerTests: XCTestCase {

    // MARK: - Accepts

    func testExtractsHyphenatedEightDigitPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123-45-678"), "12345678")
    }

    func testExtractsHyphenatedSevenDigitPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "12-345-67"), "1234567")
    }

    func testExtractsPlainSevenDigitRun() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "1234567"), "1234567")
    }

    func testExtractsMiddleDotSeparatedPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123·45·678"), "12345678")
    }

    func testExtractsLegacySixDigitPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123-456"), "123456")
    }

    func testExtractsPlateFromSurroundingText() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "ישראל 556-93-79 IL"), "5569379")
    }

    // MARK: - Separator normalization (OCR renders plate dots unpredictably)

    func testExtractsBulletOperatorSeparatedPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123∙45∙678"), "12345678") // U+2219
    }

    func testExtractsDotOperatorSeparatedPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123⋅45⋅678"), "12345678") // U+22C5
    }

    func testExtractsColonSeparatedPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123:45:678"), "12345678")
    }

    func testExtractsAsteriskSeparatedPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123*45*678"), "12345678")
    }

    func testExtractsNoBreakSpaceSeparatedPlate() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123\u{00A0}45\u{00A0}678"), "12345678")
    }

    func testCollapsesSeparatorRuns() {
        XCTAssertEqual(PlateRecognizer.extractPlate(from: "123 - 45 - 678"), "12345678")
    }

    func testRejectsHyphenatedPhoneNumber() {
        XCTAssertNil(PlateRecognizer.extractPlate(from: "050-1234567"))
    }

    func testRejectsDate() {
        XCTAssertNil(PlateRecognizer.extractPlate(from: "12.6.2024"))
    }

    func testDoesNotTreatLettersAsSeparators() {
        // "B" is likely a misread digit — dropping it would accept a wrong
        // plate ("1234567"), so letters must break the run instead.
        XCTAssertNil(PlateRecognizer.extractPlate(from: "12B345 67"))
    }

    // MARK: - Rejects

    func testRejectsFiveDigits() {
        XCTAssertNil(PlateRecognizer.extractPlate(from: "12345"))
    }

    func testRejectsPhoneNumber() {
        // A 10-digit run must not be truncated into a "plate".
        XCTAssertNil(PlateRecognizer.extractPlate(from: "0501234567"))
    }

    func testRejectsDigitsEmbeddedInLongerRun() {
        XCTAssertNil(PlateRecognizer.extractPlate(from: "123456789012"))
    }

    func testRejectsTextWithoutDigits() {
        XCTAssertNil(PlateRecognizer.extractPlate(from: "מספר רכב"))
    }

    // MARK: - Canonical Israeli print formats (single-frame accept)

    func testEightDigitPrintFormatIsCanonical() {
        let candidate = PlateRecognizer.candidates(in: "123-45-678").first
        XCTAssertEqual(candidate?.groups, [3, 2, 3])
        XCTAssertEqual(candidate?.isCanonicalFormat, true)
    }

    func testSevenDigitPrintFormatIsCanonical() {
        let candidate = PlateRecognizer.candidates(in: "12-345-67").first
        XCTAssertEqual(candidate?.groups, [2, 3, 2])
        XCTAssertEqual(candidate?.isCanonicalFormat, true)
    }

    /// A truncated 8-digit plate ("123-45-678" losing its last digit) still
    /// has 7 digits but the wrong group shape — it must NOT be canonical, so
    /// the scanner waits for stable frames instead of accepting a bad read.
    func testTruncatedEightDigitReadIsNotCanonical() {
        let candidate = PlateRecognizer.candidates(in: "123-45-67").first
        XCTAssertEqual(candidate?.groups, [3, 2, 2])
        XCTAssertEqual(candidate?.isCanonicalFormat, false)
    }

    func testPlainDigitRunIsNotCanonical() {
        XCTAssertEqual(PlateRecognizer.candidates(in: "1234567").first?.isCanonicalFormat, false)
    }

    // MARK: - Best candidate across a camera frame's items

    func testBestCandidatePrefersCanonicalPlateOverOtherText() {
        let best = PlateRecognizer.bestCandidate(in: ["שנת 2020", "556937", "123-45-678"])
        XCTAssertEqual(best?.digits, "12345678")
    }

    func testBestCandidatePrefersSevenDigitsOverLegacySix() {
        let best = PlateRecognizer.bestCandidate(in: ["123456", "5569379"])
        XCTAssertEqual(best?.digits, "5569379")
    }

    func testBestCandidateNilWhenNoPlateShapedText() {
        XCTAssertNil(PlateRecognizer.bestCandidate(in: ["יונדאי", "0501234567", ""]))
    }

    // MARK: - Line merging (VisionKit splits a plate into per-group items)

    /// A fragment on the default line: y-center 100, text height 20.
    private func fragment(_ transcript: String, minX: Double, maxX: Double,
                          midY: Double = 100, height: Double = 20) -> PlateRecognizer.TextObservation {
        .init(transcript: transcript, minX: minX, maxX: maxX, midY: midY, height: height)
    }

    private func bestMerged(_ items: [PlateRecognizer.TextObservation]) -> PlateRecognizer.Candidate? {
        PlateRecognizer.bestCandidate(in: PlateRecognizer.plateTranscripts(from: items))
    }

    func testMergesSplitEightDigitGroupsIntoCanonicalPlate() {
        let best = bestMerged([fragment("123", minX: 0, maxX: 60),
                               fragment("45", minX: 70, maxX: 110),
                               fragment("678", minX: 120, maxX: 180)])
        XCTAssertEqual(best?.digits, "12345678")
        XCTAssertEqual(best?.isCanonicalFormat, true)
    }

    func testMergesSplitSevenDigitGroupsIntoCanonicalPlate() {
        let best = bestMerged([fragment("12", minX: 0, maxX: 40),
                               fragment("345", minX: 50, maxX: 110),
                               fragment("67", minX: 120, maxX: 160)])
        XCTAssertEqual(best?.digits, "1234567")
        XCTAssertEqual(best?.isCanonicalFormat, true)
    }

    func testMergeOrderIsLeftToRightRegardlessOfInputOrder() {
        let best = bestMerged([fragment("678", minX: 120, maxX: 180),
                               fragment("123", minX: 0, maxX: 60),
                               fragment("45", minX: 70, maxX: 110)])
        XCTAssertEqual(best?.digits, "12345678")
    }

    func testDoesNotMergeAcrossLines() {
        // Two 3-digit groups stacked vertically are not one 6-digit plate.
        XCTAssertNil(bestMerged([fragment("123", minX: 0, maxX: 60, midY: 100),
                                 fragment("456", minX: 0, maxX: 60, midY: 200)]))
    }

    func testDoesNotMergeAcrossLargeHorizontalGap() {
        // Same line, but half a screen apart — unrelated bumper text.
        XCTAssertNil(bestMerged([fragment("123", minX: 0, maxX: 60),
                                 fragment("456", minX: 560, maxX: 620)]))
    }

    func testStrayDigitOnSameLineDoesNotPoisonPlateWindow() {
        let best = bestMerged([fragment("123", minX: 0, maxX: 60),
                               fragment("45", minX: 70, maxX: 110),
                               fragment("678", minX: 120, maxX: 180),
                               fragment("9", minX: 190, maxX: 210)])
        XCTAssertEqual(best?.digits, "12345678")
        XCTAssertEqual(best?.isCanonicalFormat, true)
    }

    func testIgnoresNonDigitFragmentsWhenMerging() {
        // The "IL" country strip sits right next to the digits on a real plate.
        let best = bestMerged([fragment("IL", minX: -30, maxX: -10),
                               fragment("123", minX: 0, maxX: 60),
                               fragment("45", minX: 70, maxX: 110),
                               fragment("678", minX: 120, maxX: 180)])
        XCTAssertEqual(best?.digits, "12345678")
    }

    func testPlateTranscriptsKeepPerItemTranscripts() {
        // A whole-plate single item must keep working exactly as before.
        let transcripts = PlateRecognizer.plateTranscripts(
            from: [fragment("123-45-678", minX: 0, maxX: 180)])
        XCTAssertTrue(transcripts.contains("123-45-678"))
    }

    // MARK: - Viewfinder geometry (the cutout IS the plate)

    /// iPhone-sized scanner view and its cutout, shared by the geometry tests.
    private let viewSize = CGSize(width: 393, height: 852)
    private var cutout: CGRect { PlateViewfinder.cutout(in: viewSize) }

    /// A fragment vertically centered in the cutout at plate-digit height
    /// (~0.7× cutout height) unless overridden.
    private func plateFragment(_ transcript: String, minX: Double, maxX: Double,
                               midY: Double? = nil, height: Double = 50) -> PlateRecognizer.TextObservation {
        .init(transcript: transcript, minX: minX, maxX: maxX,
              midY: midY ?? Double(cutout.midY), height: height)
    }

    func testViewfinderAcceptsPlateSizedTextInsideCutout() {
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("123∙45∙678", minX: Double(cutout.minX) + 10,
                                 maxX: Double(cutout.maxX) - 10)],
            cutout: cutout)
        XCTAssertEqual(best?.digits, "12345678")
        XCTAssertEqual(best?.isCanonicalFormat, true)
    }

    func testViewfinderMergesSplitGroupsInsideCutout() {
        let x = Double(cutout.minX)
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("123", minX: x, maxX: x + 80),
                   plateFragment("45", minX: x + 100, maxX: x + 160),
                   plateFragment("678", minX: x + 180, maxX: x + 260)],
            cutout: cutout)
        XCTAssertEqual(best?.digits, "12345678")
        XCTAssertEqual(best?.isCanonicalFormat, true)
    }

    func testViewfinderIgnoresSmallTextInsideRegion() {
        // Dealer-frame text: right position, but ~0.15× cutout height.
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("123-45-678", minX: Double(cutout.minX) + 10,
                                 maxX: Double(cutout.maxX) - 10, height: 11)],
            cutout: cutout)
        XCTAssertNil(best)
    }

    func testViewfinderIgnoresTextOutsideRegion() {
        // Plate-sized digits, but a full cutout-height above the region.
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("123-45-678", minX: Double(cutout.minX) + 10,
                                 maxX: Double(cutout.maxX) - 10,
                                 midY: Double(cutout.minY - 2 * cutout.height))],
            cutout: cutout)
        XCTAssertNil(best)
    }

    func testViewfinderAcceptsDistantPlate() {
        // A plate filling under half the cutout still reads (height 0.28×) —
        // guards against re-tightening the minimum-height threshold.
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("123-45-678", minX: Double(cutout.midX) - 60,
                                 maxX: Double(cutout.midX) + 60,
                                 height: Double(cutout.height) * 0.28)],
            cutout: cutout)
        XCTAssertEqual(best?.digits, "12345678")
    }

    func testViewfinderRelativeFilterDropsSubPlateText() {
        // A stray digit at half the plate's text height on the same line must
        // not poison the canonical read.
        let x = Double(cutout.minX)
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("123", minX: x, maxX: x + 80),
                   plateFragment("45", minX: x + 100, maxX: x + 160),
                   plateFragment("678", minX: x + 180, maxX: x + 260),
                   plateFragment("9", minX: x + 270, maxX: x + 290, height: 20)],
            cutout: cutout)
        XCTAssertEqual(best?.digits, "12345678")
        XCTAssertEqual(best?.isCanonicalFormat, true)
    }

    func testViewfinderRejectsLargePhoneNumber() {
        // Even plate-sized and in-cutout, a phone number's run shape fails.
        let best = PlateRecognizer.viewfinderCandidate(
            from: [plateFragment("09-1234567", minX: Double(cutout.minX) + 10,
                                 maxX: Double(cutout.maxX) - 10)],
            cutout: cutout)
        XCTAssertNil(best)
    }

    // MARK: - Acceptance tiers

    func testFramesRequiredInstantForCanonicalGeometryRead() {
        let canonical = PlateRecognizer.candidates(in: "123-45-678").first!
        XCTAssertEqual(PlateRecognizer.framesRequired(for: canonical, geometryVerified: true), 1)
    }

    func testFramesRequiredInstantForSingleRunSevenDigits() {
        let run = PlateRecognizer.candidates(in: "1234567").first! // groups [7]
        XCTAssertEqual(PlateRecognizer.framesRequired(for: run, geometryVerified: true), 1)
    }

    func testFramesRequiredExtraFrameForNonCanonicalSeven() {
        let truncated = PlateRecognizer.candidates(in: "123-45-67").first! // [3,2,2]
        XCTAssertEqual(PlateRecognizer.framesRequired(for: truncated, geometryVerified: true), 2)
    }

    func testFramesRequiredExtraFrameForStrayMergedEight() {
        // Documents the "no blanket instant-8" decision: a 7-digit plate plus
        // a merged stray digit also totals 8.
        let merged = PlateRecognizer.Candidate(digits: "12345678", groups: [2, 3, 2, 1])
        XCTAssertEqual(PlateRecognizer.framesRequired(for: merged, geometryVerified: true), 2)
    }

    func testFramesRequiredSlowestForSixDigits() {
        let legacy = PlateRecognizer.candidates(in: "123-456").first!
        XCTAssertEqual(PlateRecognizer.framesRequired(for: legacy, geometryVerified: true), 3)
    }

    func testFramesRequiredExtraFrameWithoutGeometry() {
        let canonical = PlateRecognizer.candidates(in: "123-45-678").first!
        XCTAssertEqual(PlateRecognizer.framesRequired(for: canonical, geometryVerified: false), 2)
    }

    // MARK: - Display formatting

    func testFormatsCandidateWithPrintedGroups() {
        let candidate = PlateRecognizer.candidates(in: "123-45-678").first!
        XCTAssertEqual(PlateRecognizer.formatted(candidate), "123-45-678")
    }

    func testFormatsPlainRunWithoutSeparators() {
        let candidate = PlateRecognizer.candidates(in: "1234567").first!
        XCTAssertEqual(PlateRecognizer.formatted(candidate), "1234567")
    }
}

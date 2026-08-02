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
}

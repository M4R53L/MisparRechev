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
}

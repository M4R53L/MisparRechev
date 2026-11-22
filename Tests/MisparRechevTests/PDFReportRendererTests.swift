import CoreGraphics
import XCTest
@testable import MisparRechev

/// PDF export: a single-page vector PDF, content-sized at the fixed report
/// width, named after the plate. (Runs in the app-hosted test bundle so
/// `ImageRenderer` has a UI context.)
@MainActor
final class PDFReportRendererTests: XCTestCase {

    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            throw NSError(domain: "test", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "missing fixture \(name).json"])
        }
        return try Data(contentsOf: url)
    }

    private func fullResult() throws -> LookupResult {
        func record<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
            try XCTUnwrap(
                JSONDecoder().decode(DataGovResponse<T>.self, from: fixture(name))
                    .result?.records?.first)
        }
        return LookupResult(
            vehicle: try record(Vehicle.self, "primary_5970065"),
            spec: try record(VehicleSpec.self, "specs_5970065"),
            mileage: try record(VehicleHistory.self, "history_5970065"),
            ownership: try XCTUnwrap(
                JSONDecoder().decode(DataGovResponse<OwnershipRecord>.self,
                                     from: fixture("ownership_3256880")).result?.records),
            recalls: [try record(RecallRecord.self, "recall_5569379")],
            prices: []
        )
    }

    func testRendersSinglePageVectorPDFNamedAfterPlate() throws {
        let url = try PDFReportRenderer.render(result: try fullResult())
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url.lastPathComponent, "דוח-רכב-5970065.pdf")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let document = try XCTUnwrap(CGPDFDocument(url as CFURL))
        XCTAssertEqual(document.numberOfPages, 1)
        let page = try XCTUnwrap(document.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        XCTAssertEqual(box.width, PDFReportView.pageWidth, accuracy: 0.5)
        XCTAssertGreaterThan(box.height, 200, "content-sized page has real height")

        let byteCount = try Data(contentsOf: url).count
        XCTAssertGreaterThan(byteCount, 5_000, "non-trivial vector content")
    }

    /// Set `PDF_PREVIEW_DIR` to a host folder to keep a copy of the rendered
    /// report for visual review (the simulator can write to host paths).
    func testExportsPreviewCopyWhenRequested() throws {
        guard let dir = ProcessInfo.processInfo.environment["PDF_PREVIEW_DIR"] else {
            throw XCTSkip("PDF_PREVIEW_DIR not set")
        }
        var result = try fullResult()
        let price = try XCTUnwrap(
            JSONDecoder().decode(DataGovResponse<NewCarPrice>.self,
                                 from: fixture("price_77720101")).result?.records?.first)
        result = LookupResult(vehicle: result.vehicle, spec: result.spec, mileage: result.mileage,
                              ownership: result.ownership, recalls: result.recalls,
                              prices: [price], electricRangeKm: nil)
        let url = try PDFReportRenderer.render(result: result)
        let target = URL(fileURLWithPath: dir).appendingPathComponent("report.pdf")
        try? FileManager.default.removeItem(at: target)
        try FileManager.default.copyItem(at: url, to: target)
    }
}

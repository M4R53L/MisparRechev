import XCTest
@testable import MisparRechev

/// Pure-geometry tests for the scanner's shared viewfinder math.
final class PlateViewfinderTests: XCTestCase {

    private let size = CGSize(width: 393, height: 852)

    func testCutoutIsCenteredWithPlateAspect() {
        let cutout = PlateViewfinder.cutout(in: size)
        XCTAssertEqual(cutout.width, 393 * 0.85, accuracy: 0.001)
        XCTAssertEqual(cutout.width / cutout.height, 4.6, accuracy: 0.001)
        XCTAssertEqual(cutout.midX, 196.5, accuracy: 0.001)
        XCTAssertEqual(cutout.midY, 426, accuracy: 0.001)
    }

    func testAcceptanceRegionExpandsByTolerances() {
        let cutout = PlateViewfinder.cutout(in: size)
        let region = PlateViewfinder.acceptanceRegion(for: cutout)
        XCTAssertEqual(region.minY, cutout.minY - cutout.height * 0.4, accuracy: 0.001)
        XCTAssertEqual(region.maxY, cutout.maxY + cutout.height * 0.4, accuracy: 0.001)
        XCTAssertEqual(region.minX, cutout.minX - cutout.width * 0.06, accuracy: 0.001)
        XCTAssertEqual(region.maxX, cutout.maxX + cutout.width * 0.06, accuracy: 0.001)
    }

    func testRegionOfInterestStaysInsideViewBounds() {
        let roi = PlateViewfinder.regionOfInterest(in: size)
        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(roi))
        XCTAssertFalse(roi.isEmpty)
    }

    func testRegionOfInterestForDegenerateSizesDoesNotCrash() {
        _ = PlateViewfinder.regionOfInterest(in: .zero)
        _ = PlateViewfinder.regionOfInterest(in: CGSize(width: 10, height: 10))
    }
}

import XCTest
import UIKit
@testable import MisparRechev

final class CarBrandTests: XCTestCase {

    func testResolvesBrandFromRegistryNameWithCountry() {
        XCTAssertEqual(CarBrands.brand(forManufacturer: "מזדה יפן"),
                       CarBrand(name: "מזדה", slug: "mazda"))
        XCTAssertEqual(CarBrands.brand(forManufacturer: "פולקסווגן גרמנ")?.slug, "volkswagen")
        XCTAssertEqual(CarBrands.brand(forManufacturer: "ב מ וו ארהב\"")?.slug, "bmw")
        XCTAssertEqual(CarBrands.brand(forManufacturer: " טויוטה טורקיה ")?.slug, "toyota")
    }

    func testLongerPrefixWinsOverShorterBrand() {
        // "פיאט קרייזלר" is the FCA group, not Fiat; "מרוטי סוזוקי" is Suzuki.
        XCTAssertNil(CarBrands.brand(forManufacturer: "פיאט קרייזלר")?.slug)
        XCTAssertEqual(CarBrands.brand(forManufacturer: "פיאט איטליה")?.slug, "fiat")
        XCTAssertEqual(CarBrands.brand(forManufacturer: "מרוטי סוזוקי")?.slug, "suzuki")
    }

    func testLatinNamesAndUnknowns() {
        XCTAssertEqual(CarBrands.brand(forManufacturer: "Toyota")?.slug, "toyota")
        XCTAssertNil(CarBrands.brand(forManufacturer: "יצרן לא מוכר"))
        XCTAssertNil(CarBrands.brand(forManufacturer: nil))
        XCTAssertNil(CarBrands.brand(forManufacturer: "  "))
    }

    /// Every slug in the table must have a bundled logo, or the badge would
    /// silently fall back to a monogram.
    func testEveryMappedLogoIsBundled() {
        let names = ["אאודי", "ב מ וו", "טויוטה", "יונדאי", "קיה", "מזדה", "סקודה", "טסלה",
                     "בי ווי די", "מ.ג'י", "רנו", "פיג'ו", "סיטרואן", "מרצדס בנץ גרמנ",
                     "שברולט", "פורד", "הונדה", "ניסאן", "סוזוקי", "סובארו", "מיצובישי",
                     "וולבו", "סיאט", "אופל", "פיאט", "ג'יפ", "לקסוס", "דאצ'יה", "צ'רי",
                     "ג'ילי", "רובר אנגליה", "פורשה", "יגואר", "אלפא רומיאו_אי"]
        for name in names {
            guard let slug = CarBrands.brand(forManufacturer: name)?.slug else {
                XCTFail("no logo slug for \(name)"); continue
            }
            XCTAssertNotNil(UIImage(named: "Brands/\(slug)", in: Bundle(for: AppBundleMarker.self),
                                    compatibleWith: nil) ?? UIImage(named: "Brands/\(slug)"),
                            "missing bundled logo \(slug)")
        }
    }

    func testReportTitleAndTrim() {
        let vehicle = Vehicle.preview
        XCTAssertEqual(vehicle.trimLevel, "S")
        XCTAssertEqual(vehicle.reportTitle, "מזדה MX 5")
    }

    func testPlateFormat() {
        XCTAssertEqual(PlateFormat.dashed("5970065"), "59-700-65")
        XCTAssertEqual(PlateFormat.dashed("77720101"), "777-20-101")
        XCTAssertEqual(PlateFormat.dashed("123456"), "123456")
    }
}

private final class AppBundleMarker {}

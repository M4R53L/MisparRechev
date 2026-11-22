import XCTest

/// Captures App Store screenshots by driving the real UI with known test
/// plates (live network required). Extract with:
/// `xcrun xcresulttool export attachments --path <bundle>.xcresult --output-path <dir>`
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The app under test, launched past the first-run guide.
    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-hasSeenOnboarding", "YES"]
        return app
    }

    private func shoot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func search(_ app: XCUIApplication, plate: String) {
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "plate field not found")
        field.tap()
        field.typeText(plate)
        let searchButton = app.buttons["חיפוש"].firstMatch
        XCTAssertTrue(searchButton.waitForExistence(timeout: 5), "search button not found")
        searchButton.tap()
        // ResultView is up once "חיפוש חדש" exists.
        let newSearch = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'חיפוש חדש'")).firstMatch
        XCTAssertTrue(newSearch.waitForExistence(timeout: 30), "result view for \(plate) did not load")
        sleep(3) // let the optional sections (price/spec/range) fill in
    }

    func testCaptureScreenshots() throws {
        let app = makeApp()
        app.launch()
        sleep(2)
        shoot("01-home")

        search(app, plate: "5970065")
        shoot("02-result-top")
        app.swipeUp()
        sleep(1)
        shoot("03-result-details")
        app.swipeUp()
        sleep(1)
        shoot("04-result-more")

        app.terminate()
        app.launch()
        search(app, plate: "3256880")
        for _ in 0..<4 { app.swipeUp() }
        sleep(1)
        shoot("05-safety")

        app.terminate()
        app.launch()
        search(app, plate: "94230401")
        shoot("06-recall")
    }

    /// The ownership/mileage section sits just below the plate header — a full
    /// swipe overshoots it, so scroll with small precise drags instead.
    func testOwnershipScroll() throws {
        let app = makeApp()
        app.launch()
        search(app, plate: "3256880")
        var step = 0
        func drag(by dy: CGFloat) {
            step += 1
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75 - dy))
            start.press(forDuration: 0.1, thenDragTo: end)
            sleep(2)
            shoot("fine-\(step)")
        }
        drag(by: 0.30)
        drag(by: 0.04)
        drag(by: 0.04)
    }

    /// Copy-toast (transient, 2.5 s), pinned "הרכב שלי" card, home-screen widget.
    func testExtraScreens() throws {
        let app = makeApp()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        app.launch()

        // 1. The copied-to-clipboard toast — shoot immediately after load.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("5970065")
        app.buttons["חיפוש"].firstMatch.tap()
        let newSearch = app.buttons.matching(
            NSPredicate(format: "label CONTAINS 'חיפוש חדש'")).firstMatch
        XCTAssertTrue(newSearch.waitForExistence(timeout: 30))
        shoot("08-copied")

        // 2. Pin as "הרכב שלי" (allow the notification permission alert), then
        //    the home screen shows the my-car card.
        let pin = app.buttons["הצמד כרכב שלי"].firstMatch
        if pin.exists {  // already pinned on reruns — don't toggle it off
            pin.tap()
            let allow = springboard.alerts.buttons["Allow"]
            if allow.waitForExistence(timeout: 5) { allow.tap() }
        }
        sleep(2)
        app.terminate()
        app.launch()
        sleep(3)
        shoot("09-mycar")

        // 3. Home-screen widget: add via the widget gallery.
        app.terminate()
        XCUIDevice.shared.press(.home)
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(1)

        // Enter jiggle mode — try several spots; an app icon under the press
        // opens a context menu instead, so verify Edit/Done actually appeared.
        var jiggling = false
        for spot in [CGVector(dx: 0.9, dy: 0.8), CGVector(dx: 0.5, dy: 0.85),
                     CGVector(dx: 0.1, dy: 0.75)] where !jiggling {
            springboard.coordinate(withNormalizedOffset: spot).press(forDuration: 2.0)
            sleep(2)
            jiggling = springboard.buttons["Edit"].exists
                || springboard.buttons["Add Widget"].exists
                || springboard.buttons["Done"].exists
            if !jiggling {  // dismiss a stray context menu
                springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
                sleep(1)
            }
        }
        shoot("dbg-jiggle")
        XCTAssertTrue(jiggling, "never entered home-screen edit mode")

        if springboard.buttons["Edit"].exists {
            springboard.buttons["Edit"].tap()
            sleep(1)
        }
        if springboard.buttons["Add Widget"].waitForExistence(timeout: 3) {
            springboard.buttons["Add Widget"].tap()
        }
        // chronod fills the gallery lazily on simulators — poll up to ~45 s.
        var waited = 0
        while springboard.cells.count == 0 && waited < 45 {
            sleep(3)
            waited += 3
        }
        sleep(3)
        shoot("dbg-gallery")

        // Only a hittable match counts — the app's home-screen icon behind the
        // sheet has the same label with a zero frame.
        let byLabel = springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'מספר רכב'"))
        func hittableEntry() -> XCUIElement? {
            byLabel.allElementsBoundByIndex.first { $0.isHittable }
        }
        var entry = hittableEntry()
        var tries = 0
        while entry == nil && tries < 30 {
            springboard.swipeUp(velocity: .slow)
            tries += 1
            entry = hittableEntry()
        }
        shoot("dbg-entry")
        guard let entry else {
            XCTFail("widget gallery entry not found")
            return
        }
        entry.tap()
        sleep(2)
        if springboard.buttons["Add Widget"].waitForExistence(timeout: 5) {
            springboard.buttons["Add Widget"].tap()
        }
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(1)
        XCUIDevice.shared.press(.home)
        sleep(2)
        shoot("10-widget")
    }
}

extension ScreenshotTests {
    /// Walks the first-run guide and captures each step.
    func testOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-hasSeenOnboarding", "NO"]
        app.launch()
        XCTAssertTrue(app.buttons["בואו נתחיל"].waitForExistence(timeout: 10))
        sleep(1)
        shoot("ob-1-welcome")
        app.buttons["בואו נתחיל"].tap()
        for n in 2...4 {
            sleep(2)
            shoot("ob-\(n)")
            app.buttons["המשך"].tap()
        }
        sleep(1)
        shoot("ob-5-try")
    }
}

import XCTest

final class E2E_Tests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--uitesting"]
    }

    func testScanTicketFromTicketsList() throws {
        // Prepare a known test code in env
        let testCode = "idsz5c2nxm3khfncuundpnztuprbuk7w"
        app.launchEnvironment["UITEST_SCAN_CODE"] = testCode
        app.launch()

        // Tap Tickets tab (tab bar label might be accessible as a button)
        let ticketsButton = app.buttons["Tickets"]
        XCTAssertTrue(ticketsButton.waitForExistence(timeout: 5))
        ticketsButton.tap()

        // Tap scan toolbar button
        let scanButton = app.buttons["TicketsScanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        scanButton.tap()

        // Wait for scanner to appear and inject scan via hidden button
        let injectButton = app.buttons["UITestInjectScanButton"]
        XCTAssertTrue(injectButton.waitForExistence(timeout: 5))
        injectButton.tap()

        // Wait for toast indicating success or failure (use accessibility id)
        let toastButton = app.buttons["ScanToast"]
        XCTAssertTrue(toastButton.waitForExistence(timeout: 6), "Expected a scan result toast to appear")
        // Dismiss the toast
        toastButton.tap()

        // Ensure ticket list refreshes and shows the ticket as used (expecting 'Used' somewhere)
        let usedPredicate = NSPredicate(format: "label CONTAINS[c] 'used'")
        let usedElement = app.staticTexts.containing(usedPredicate).element
        XCTAssertTrue(usedElement.waitForExistence(timeout: 8), "Expected ticket to show as used after scan")
    }

    func testMediaLibraryDisplaysAllItems() throws {
        app.launch()
        let eventsButton = app.buttons["Events"]
        XCTAssertTrue(eventsButton.waitForExistence(timeout: 5))
        eventsButton.tap()

        // Open any event, then open edit -> Media Library (this depends on UI structure)
        // For robust test, search for a button that opens media library
        let mediaButton = app.buttons["Media Library"]
        if mediaButton.waitForExistence(timeout: 5) {
            mediaButton.tap()
            // Wait for collection to load
            let firstThumbnail = app.images.firstMatch
            XCTAssertTrue(firstThumbnail.waitForExistence(timeout: 10))

            // Tap debug log button to assert it's present and doesn't crash
            let debugButton = app.buttons["MediaDebugLogButton"]
            if debugButton.waitForExistence(timeout: 3) {
                debugButton.tap()
            }
        } else {
            XCTFail("Media Library entry point not found")
        }
    }
}

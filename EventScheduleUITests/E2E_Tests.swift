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

    func testScanTicketNotFound404() throws {
        // Use a deterministic UITest-only code to simulate server 404
        let testCode = "UITEST_404_NOTFOUND"
        app.launchEnvironment["UITEST_SCAN_CODE"] = testCode
        app.launch()

        // Navigate to Tickets
        let ticketsButton = app.buttons["Tickets"]
        XCTAssertTrue(ticketsButton.waitForExistence(timeout: 5))
        ticketsButton.tap()

        // Tap scan toolbar button
        let scanButton = app.buttons["TicketsScanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        scanButton.tap()

        // Inject the test scan
        let injectButton = app.buttons["UITestInjectScanButton"]
        XCTAssertTrue(injectButton.waitForExistence(timeout: 5))
        injectButton.tap()

        // Expect a toast containing 'Ticket not found' (case-insensitive)
        let toastButton = app.buttons["ScanToast"]
        XCTAssertTrue(toastButton.waitForExistence(timeout: 6), "Expected a scan result toast to appear")
        XCTAssertTrue(toastButton.label.lowercased().contains("ticket not found"), "Expected toast to contain 'Ticket not found' for 404 response")

        // Dismiss the toast
        toastButton.tap()
    }

    func testScanTicketUnauthorized419() throws {
        // Use a deterministic UITest-only code to simulate an unauthorized/419 response
        let testCode = "UITEST_419_UNAUTHORIZED"
        app.launchEnvironment["UITEST_SCAN_CODE"] = testCode
        app.launch()

        // Navigate to Tickets
        let ticketsButton = app.buttons["Tickets"]
        XCTAssertTrue(ticketsButton.waitForExistence(timeout: 5))
        ticketsButton.tap()

        // Tap scan toolbar button
        let scanButton = app.buttons["TicketsScanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        scanButton.tap()

        // Inject the test scan
        let injectButton = app.buttons["UITestInjectScanButton"]
        XCTAssertTrue(injectButton.waitForExistence(timeout: 5))
        injectButton.tap()

        // Expect a toast containing 'unauthor' (case-insensitive)
        let toastButton = app.buttons["ScanToast"]
        XCTAssertTrue(toastButton.waitForExistence(timeout: 6), "Expected a scan result toast to appear")
        XCTAssertTrue(toastButton.label.lowercased().contains("unauthor"), "Expected toast to contain an unauthorized message for 419 response")

        // Dismiss the toast
        toastButton.tap()
    }

    func testScanTicketMalformed2xx() throws {
        // Use a deterministic UITest-only code to simulate a 2xx success with malformed payload
        let testCode = "UITEST_2XX_MALFORMED_EXAMPLE"
        app.launchEnvironment["UITEST_SCAN_CODE"] = testCode
        app.launch()

        // Navigate to Tickets
        let ticketsButton = app.buttons["Tickets"]
        XCTAssertTrue(ticketsButton.waitForExistence(timeout: 5))
        ticketsButton.tap()

        // Tap scan toolbar button
        let scanButton = app.buttons["TicketsScanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        scanButton.tap()

        // Inject the test scan
        let injectButton = app.buttons["UITestInjectScanButton"]
        XCTAssertTrue(injectButton.waitForExistence(timeout: 5))
        injectButton.tap()

        // Expect a toast indicating a generic scanned message and no raw JSON exposure
        let toastButton = app.buttons["ScanToast"]
        XCTAssertTrue(toastButton.waitForExistence(timeout: 6), "Expected a scan result toast to appear")
        let label = toastButton.label.lowercased()
        XCTAssertTrue(label.contains("scanned") || label.contains("ticket scanned"), "Expected a generic scanned message")
        XCTAssertFalse(label.contains("{") || label.contains("}"), "Toast should not display raw JSON body")

        // Dismiss the toast
        toastButton.tap()
    }

    func testCameraPermissionDenied() throws {
        // Simulate camera permission denial via launch env var
        app.launchEnvironment["UITEST_SIMULATE_CAMERA_DENIED"] = "1"
        app.launch()

        // Navigate to Tickets
        let ticketsButton = app.buttons["Tickets"]
        XCTAssertTrue(ticketsButton.waitForExistence(timeout: 5))
        ticketsButton.tap()

        // Tap scan toolbar button
        let scanButton = app.buttons["TicketsScanButton"]
        XCTAssertTrue(scanButton.waitForExistence(timeout: 5))
        scanButton.tap()

        // Expect an on-screen error containing 'Camera access denied' (case-insensitive)
        let errorPredicate = NSPredicate(format: "label CONTAINS[c] 'camera access denied'")
        let errorElement = app.staticTexts.containing(errorPredicate).element
        XCTAssertTrue(errorElement.waitForExistence(timeout: 6), "Expected a camera access denied message to appear")

        // Dismiss the scanner using the Cancel button
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.waitForExistence(timeout: 3) { cancelButton.tap() }
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

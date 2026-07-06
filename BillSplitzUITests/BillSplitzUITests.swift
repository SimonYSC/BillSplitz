//
//  BillSplitzUITests.swift
//  BillSplitzUITests
//
//  Created by Simon Chao on 11/17/25.
//

import XCTest

final class BillSplitzUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testCompletesSimulatorMVPFlowWithSampleReceipt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-draft"]
        app.launch()

        app.buttons["start-new-split-button"].tap()
        XCTAssertTrue(app.staticTexts["screen-title-sessionSetup"].waitForExistence(timeout: 2))

        let nextButton = app.buttons["flow-next-button"]
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["screen-title-receiptCapture"].waitForExistence(timeout: 2))

        app.buttons["use-sample-receipt-button"].tap()
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["screen-title-receiptReview"].waitForExistence(timeout: 2))

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["screen-title-splitBoard"].waitForExistence(timeout: 2))

        assignItem("Pad Thai", to: "You", in: app)
        assignItem("Green Curry", to: "You", in: app)
        assignItem("Thai Iced Tea", to: "Alex", in: app)

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["screen-title-settlement"].waitForExistence(timeout: 2))

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["screen-title-share"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["share-summary-text"].waitForExistence(timeout: 2))

        nextButton.tap()
        XCTAssertTrue(app.buttons["start-new-split-button"].waitForExistence(timeout: 2))
    }

    private func assignItem(_ itemName: String, to participantName: String, in app: XCUIApplication) {
        let modeButton = app.buttons["mode-\(itemName)-assigned"]
        scrollIntoView(modeButton, in: app)
        modeButton.tap()

        let assignButton = app.buttons["assign-\(itemName)-\(participantName)"]
        scrollIntoView(assignButton, in: app)
        assignButton.tap()
        waitForSelected(assignButton)
    }

    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        var attempts = 0
        while !element.isHittable && attempts < 6 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        XCTAssertTrue(element.isHittable, "\(element.identifier) never became hittable after scrolling")
    }

    private func waitForSelected(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // ==[c]: the Tab reskin's textCase environment uppercases accessibility values on iOS 26.
        let predicate = NSPredicate(format: "value ==[c] %@", "Selected")
        expectation(for: predicate, evaluatedWith: element)
        waitForExpectations(timeout: 2)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

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
        app.launchArguments = ["--reset-draft", "--uitest-reduce-motion"]
        app.launchArguments += ["-hasSeenSplitBoardCoachMark", "YES"]
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

    @MainActor
    func testCoachMarkAppearsOnFirstAssignModeEntry() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-draft", "--uitest-reduce-motion"]
        app.launch()

        app.buttons["start-new-split-button"].tap()
        app.buttons["flow-next-button"].tap()
        app.buttons["use-sample-receipt-button"].tap()
        app.buttons["flow-next-button"].tap()
        app.buttons["flow-next-button"].tap()
        XCTAssertTrue(app.staticTexts["screen-title-splitBoard"].waitForExistence(timeout: 2))

        let row = app.otherElements["split-item-row-Pad Thai"]
        scrollIntoView(row, in: app)
        row.press(forDuration: 0.8)

        let coachMark = app.buttons["coach-mark-got-it"]
        XCTAssertTrue(coachMark.waitForExistence(timeout: 2))

        coachMark.tap()
        XCTAssertFalse(coachMark.exists)
    }

    private func assignItem(_ itemName: String, to participantName: String, in app: XCUIApplication) {
        // Coordinate presses: SwiftUI accessibility containers flip isHittable unpredictably,
        // and element presses refuse on it; coordinates bypass that gate.
        let row = app.otherElements["split-item-row-\(itemName)"]
        scrollIntoView(row, in: app)
        let rowCenter = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        rowCenter.press(forDuration: 0.8) // enter assign mode, release

        let bubble = app.descendants(matching: .any)["assign-bubble-\(participantName)"].firstMatch
        XCTAssertTrue(bubble.waitForExistence(timeout: 2), "assign-bubble-\(participantName) missing after long press")
        // Tap-to-assign is CI's deterministic path; the drag gesture is verified on-device.
        bubble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()

        // exit assign mode by tapping the scrim (near the top, clear of bubbles), then assert the badge
        let scrim = app.descendants(matching: .any)["assign-scrim"].firstMatch
        XCTAssertTrue(scrim.waitForExistence(timeout: 2), "assign-scrim missing after drop")
        scrim.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap()
        let badge = app.descendants(matching: .any)["split-item-badge-\(itemName)"].firstMatch
        waitForConnectedName(badge, participantName)
    }

    // Frame-based visibility: SwiftUI accessibility containers report isHittable=false even
    // when fully on screen, but coordinate presses on their frames land fine.
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 2), "\(element.identifier) not found")
        let visibleBand = app.frame.insetBy(dx: 0, dy: 160)
        var attempts = 0
        while !visibleBand.contains(element.frame) && attempts < 6 {
            app.swipeUp(velocity: .slow)
            attempts += 1
        }
        XCTAssertTrue(
            visibleBand.intersects(element.frame),
            "\(element.identifier) never scrolled into the visible band"
        )
    }

    private func waitForConnectedName(
        _ element: XCUIElement,
        _ participantName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        // ==[c]: the Tab reskin's textCase environment uppercases accessibility values on iOS 26.
        let predicate = NSPredicate(format: "value CONTAINS[c] %@", participantName)
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

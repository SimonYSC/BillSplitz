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
        XCTAssertTrue(app.staticTexts["Session Setup"].waitForExistence(timeout: 2))

        let nextButton = app.buttons["flow-next-button"]
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Receipt Capture"].waitForExistence(timeout: 2))

        app.buttons["use-sample-receipt-button"].tap()
        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Receipt Review"].waitForExistence(timeout: 2))

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Split Board"].waitForExistence(timeout: 2))

        app.buttons["mode-Spicy tuna roll-assigned"].tap()
        let spicyTunaYou = app.buttons["assign-Spicy tuna roll-You"]
        spicyTunaYou.tap()
        waitForSelected(spicyTunaYou)

        app.swipeUp()
        app.buttons["mode-Green tea-split"].tap()
        let greenTeaAlex = app.buttons["assign-Green tea-Alex"]
        greenTeaAlex.tap()
        waitForSelected(greenTeaAlex)

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Settlement"].waitForExistence(timeout: 2))

        nextButton.tap()
        XCTAssertTrue(app.staticTexts["Share"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["share-summary-text"].waitForExistence(timeout: 2))

        nextButton.tap()
        XCTAssertTrue(app.buttons["start-new-split-button"].waitForExistence(timeout: 2))
    }

    private func waitForSelected(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let predicate = NSPredicate(format: "value == %@", "Selected")
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

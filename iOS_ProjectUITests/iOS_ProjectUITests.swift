//
//  iOS_ProjectUITests.swift
//  iOS_ProjectUITests
//
//  Created by 신찬솔 on 10/11/24.
//

import XCTest

final class iOS_ProjectUITests: XCTestCase {

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
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testChatKeyboardKeepsLatestVisibleAndRestoresPosition() throws {
        try verifyChatKeyboard(shortHistory: false, viaMeetingDetail: false)
    }

    @MainActor
    func testShortChatKeyboardFromMeetingDetail() throws {
        try verifyChatKeyboard(shortHistory: true, viaMeetingDetail: true)
    }

    @MainActor
    private func verifyChatKeyboard(shortHistory: Bool, viaMeetingDetail: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["--chat-keyboard-ui-test"] + (shortHistory ? ["--short-chat"] : [])
        app.launch()
        if viaMeetingDetail {
            app.buttons["모임 상세"].tap()
        } else {
            app.tabBars.buttons["채팅"].tap()
        }
        app.buttons["채팅방 열기"].tap()

        let lastMessage = app.staticTexts["chat-message-fixture-last"]
        let input = app.descendants(matching: .any).matching(identifier: "chat-composer-input").firstMatch
        XCTAssertTrue(lastMessage.waitForExistence(timeout: 10))
        XCTAssertTrue(input.waitForExistence(timeout: 5), app.debugDescription)
        let originalMessageY = lastMessage.frame.maxY
        let originalInputY = input.frame.maxY
        XCTAssertLessThan(lastMessage.frame.maxY, input.frame.minY)
        attach(app, name: "키보드 닫힘 - \(shortHistory ? "짧은 대화" : "긴 대화")")

        for cycle in 1...3 {
            input.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
            XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
            XCTAssertLessThan(lastMessage.frame.maxY, input.frame.minY)
            XCTAssertTrue(lastMessage.isHittable, "키보드가 마지막 메시지를 가리지 않아야 합니다")
            attach(app, name: "키보드 열림 \(cycle)")

            lastMessage.tap()
            let hidden = NSPredicate { _, _ in !app.keyboards.firstMatch.exists }
            expectation(for: hidden, evaluatedWith: nil)
            waitForExpectations(timeout: 5)
            XCTAssertEqual(input.frame.maxY, originalInputY, accuracy: 2)
            XCTAssertEqual(lastMessage.frame.maxY, originalMessageY, accuracy: 2)
        }

        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        input.typeText("First line\nSecond line\nThird line\nFourth line")
        XCTAssertLessThan(lastMessage.frame.maxY, input.frame.minY)
        XCTAssertLessThanOrEqual(input.frame.maxY, app.keyboards.firstMatch.frame.minY + 1)
        attach(app, name: "여러 줄 입력")
        lastMessage.tap()
        expectation(for: NSPredicate { _, _ in !app.keyboards.firstMatch.exists }, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
        XCTAssertLessThan(lastMessage.frame.maxY, input.frame.minY)
        attach(app, name: "여러 줄 입력 후 키보드 닫힘")
    }

    @MainActor
    private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

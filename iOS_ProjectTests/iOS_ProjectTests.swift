//
//  iOS_ProjectTests.swift
//  iOS_ProjectTests
//
//  Created by 신찬솔 on 10/11/24.
//

import XCTest
@testable import iOS_Project

final class iOS_ProjectTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testChatNotificationPayloadRequiresAValidRoomID() {
        XCTAssertEqual(NotificationPayloadParser.parseDestination(from: [
            "route": "meetingChat", "meetingId": "room-1", "messageId": "message-1"
        ]), .meetingChat(id: "room-1"))
        for invalidID in ["", "   ", "room/messages", String(repeating: "a", count: 129)] {
            XCTAssertNil(NotificationPayloadParser.parseDestination(from: ["route": "meetingChat", "meetingId": invalidID]))
        }
        XCTAssertNil(NotificationPayloadParser.parseDestination(from: ["route": "meetingChat"]))
        XCTAssertEqual(NotificationPayloadParser.parseDestination(from: ["route": "friendRequests"]), .friendRequests)
        XCTAssertEqual(NotificationPayloadParser.parseDestination(from: ["route": "meetingView", "meetingId": "room-1"]), .meeting(id: "room-1"))
    }

    @MainActor
    func testChatPushRoutesFromAnotherTabAndKeepsPendingDestinationUntilConsumed() {
        let router = AppRouter.shared
        let originalTab = router.selectedTabIndex
        let originalRoute = router.pendingRoute
        let originalPop = router.popToRootTab
        defer {
            router.selectedTabIndex = originalTab
            router.pendingRoute = originalRoute
            router.popToRootTab = originalPop
        }
        router.selectedTabIndex = AppTabIndex.friend.rawValue
        router.handle(.meetingChat(id: "room-1"))
        XCTAssertEqual(router.selectedTabIndex, AppTabIndex.chat.rawValue)
        XCTAssertEqual(router.popToRootTab, .friend)
        XCTAssertEqual(router.pendingRoute, .meetingChat(id: "room-1"))
        router.consume(.meetingChat(id: "room-other"))
        XCTAssertEqual(router.pendingRoute, .meetingChat(id: "room-1"))
        router.consume(.meetingChat(id: "room-1"))
        XCTAssertNil(router.pendingRoute)
    }

    @MainActor
    func testLeavingPreviousChatDoesNotClearNewlyVisibleChat() {
        let router = AppRouter.shared
        let previous = UUID()
        let current = UUID()
        router.chatDidAppear(id: "room-1", owner: previous)
        router.chatDidAppear(id: "room-2", owner: current)
        router.chatDidDisappear(owner: previous)
        XCTAssertEqual(router.visibleChatMeetingID, "room-2")
        router.chatDidDisappear(owner: current)
        XCTAssertNil(router.visibleChatMeetingID)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}

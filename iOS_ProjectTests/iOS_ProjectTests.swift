//
//  iOS_ProjectTests.swift
//  iOS_ProjectTests
//
//  Created by 신찬솔 on 10/11/24.
//

import XCTest
import UIKit
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

    func testQuickNotificationKeepsMemberCenterAndOpensTowardAvailableSpace() {
        let bounds = CGRect(x: 12, y: 70, width: 366, height: 700)
        let left = quickMenu(center: CGPoint(x: 60, y: 420), bounds: bounds)
        let middle = quickMenu(center: CGPoint(x: 195, y: 420), bounds: bounds)
        let right = quickMenu(center: CGPoint(x: 330, y: 420), bounds: bounds)

        XCTAssertEqual(left.memberCenter, CGPoint(x: 60, y: 420))
        XCTAssertEqual(middle.memberCenter, CGPoint(x: 195, y: 420))
        XCTAssertEqual(right.memberCenter, CGPoint(x: 330, y: 420))
        XCTAssertEqual(left.arrangement, .inwardRight)
        XCTAssertEqual(middle.arrangement, .radial)
        XCTAssertEqual(right.arrangement, .inwardLeft)
        for layout in [left, right] {
            XCTAssertEqual(layout.frame(for: .startingSoon).midX, layout.memberCenter.x)
            XCTAssertEqual(layout.frame(for: .runningLate).midX, layout.memberCenter.x)
            XCTAssertLessThan(layout.frame(for: .startingSoon).midY, layout.memberCenter.y)
            XCTAssertGreaterThan(layout.frame(for: .runningLate).midY, layout.memberCenter.y)
        }
        XCTAssertGreaterThan(left.frame(for: .almostThere).midX, left.memberCenter.x)
        XCTAssertGreaterThan(left.frame(for: .whereAreYou).midX, left.memberCenter.x)
        XCTAssertLessThan(right.frame(for: .almostThere).midX, right.memberCenter.x)
        XCTAssertLessThan(right.frame(for: .whereAreYou).midX, right.memberCenter.x)
    }

    func testQuickNotificationTracksTheCurrentScrolledButtonPosition() {
        let bounds = CGRect(x: 12, y: 70, width: 366, height: 700)
        // The same member's frame changes as the horizontal list scrolls.
        for x: CGFloat in [330, 195, 60, 15] {
            let layout = quickMenu(center: CGPoint(x: x, y: 420), bounds: bounds)
            XCTAssertEqual(layout.memberCenter, CGPoint(x: x, y: 420))
            assertQuickMenuFits(layout, inside: bounds)
        }
    }

    func testQuickNotificationActionsStayVisibleWithoutOverlappingAcrossScreenSizes() {
        for width: CGFloat in [320, 375, 402, 430, 768] {
            for height: CGFloat in [275, 600, 700] {
                let bounds = CGRect(x: 12, y: 70, width: width - 24, height: height)
                for x: CGFloat in [-10, 15, 60, width / 2, width - 60, width - 15, width + 10] {
                    for y in [bounds.minY + 40, bounds.minY + 80, bounds.minY + 94,
                              bounds.midY, bounds.maxY - 94, bounds.maxY - 80, bounds.maxY - 40] {
                        let layout = quickMenu(center: CGPoint(x: x, y: y), bounds: bounds)
                        XCTAssertEqual(layout.memberCenter, CGPoint(x: x, y: y))
                        assertQuickMenuFits(layout, inside: bounds)
                    }
                }
            }
        }
    }

    func testQuickNotificationUsesEqualEdgeGapsAcrossDevices() {
        for width: CGFloat in [320, 375, 402, 430, 768] {
            for height: CGFloat in [600, 700, 746] {
                let bounds = CGRect(x: 12, y: 70, width: width - 24, height: height)
                for bottomMargin: CGFloat in [93, 94, 97, 119, 180] {
                    for x: CGFloat in [60, width / 2, width - 60] {
                        let center = CGPoint(x: x, y: bounds.maxY - bottomMargin)
                        let layout = quickMenu(center: center, bounds: bounds)
                        let member = CGRect(x: center.x - 41, y: center.y - 31, width: 82, height: 62)
                        for preset in MeetingNotificationPreset.allCases {
                            let button = layout.frame(for: preset)
                            let dx = max(0, member.minX - button.maxX, button.minX - member.maxX)
                            let dy = max(0, member.minY - button.maxY, button.minY - member.maxY)
                            XCTAssertEqual(hypot(dx, dy), 8, accuracy: 0.001,
                                           "Unequal edge gap for \(preset) at \(center) in \(bounds)")
                        }
                        XCTAssertEqual(layout.memberCenter, center)
                        assertQuickMenuFits(layout, inside: bounds)
                    }
                }
            }
        }
    }

    func testQuickNotificationNearBottomKeepsCompactDirections() {
        let bounds = CGRect(x: 12, y: 70, width: 378, height: 746)
        // These margins used to trigger a two-row grid, despite room for a fan.
        for margin: CGFloat in [91, 92, 93, 94, 96, 97] {
            let y = bounds.maxY - margin
            for x: CGFloat in [60, 201, 342] {
                let layout = quickMenu(center: CGPoint(x: x, y: y), bounds: bounds)
                XCTAssertEqual(layout.memberCenter, CGPoint(x: x, y: y))
                XCTAssertEqual(layout.frame(for: .startingSoon).midX, x)
                XCTAssertEqual((y - 31) - layout.frame(for: .startingSoon).maxY, 8)
                XCTAssertEqual(layout.frame(for: .runningLate).midX, x)
                let lowerGap = layout.frame(for: .runningLate).minY - (y + 31)
                XCTAssertGreaterThanOrEqual(lowerGap, 6)
                XCTAssertLessThanOrEqual(lowerGap, 8)
                if x != 201 {
                    XCTAssertLessThan(layout.frame(for: .almostThere).midY, y)
                    XCTAssertGreaterThan(layout.frame(for: .whereAreYou).midY, y)
                }
                assertQuickMenuFits(layout, inside: bounds)
            }
        }
    }

    func testQuickNotificationOnlyMovesTheActionWithoutVerticalRoomInward() {
        let bounds = CGRect(x: 12, y: 70, width: 378, height: 746)
        for x: CGFloat in [60, 342] {
            for isNearBottom in [true, false] {
                let y = isNearBottom ? bounds.maxY - 80 : bounds.minY + 80
                let layout = quickMenu(center: CGPoint(x: x, y: y), bounds: bounds)
                let constrained: MeetingNotificationPreset = isNearBottom ? .runningLate : .startingSoon
                let opposite: MeetingNotificationPreset = isNearBottom ? .startingSoon : .runningLate
                XCTAssertEqual(layout.memberCenter, CGPoint(x: x, y: y))
                XCTAssertEqual(layout.frame(for: opposite).midX, x)
                let oppositeGap = isNearBottom
                    ? (y - 31) - layout.frame(for: opposite).maxY
                    : layout.frame(for: opposite).minY - (y + 31)
                XCTAssertEqual(oppositeGap, 8)
                for side: MeetingNotificationPreset in [.almostThere, .whereAreYou] {
                    let frame = layout.frame(for: side)
                    let gap = x < bounds.midX ? frame.minX - (x + 41) : (x - 41) - frame.maxX
                    XCTAssertEqual(gap, 8)
                }
                XCTAssertEqual(y - layout.frame(for: .almostThere).midY,
                               layout.frame(for: .whereAreYou).midY - y)
                if x < bounds.midX {
                    XCTAssertGreaterThan(layout.frame(for: constrained).midX, x)
                } else {
                    XCTAssertLessThan(layout.frame(for: constrained).midX, x)
                }
                assertQuickMenuFits(layout, inside: bounds)
            }
        }
    }

    func testQuickNotificationShortViewportOnlyMovesActions() {
        let bounds = CGRect(x: 12, y: 12, width: 700, height: 275)
        for y: CGFloat in [30, 100, 130, 180, 240, 275] {
            let layout = quickMenu(center: CGPoint(x: 60, y: y), bounds: bounds)
            XCTAssertEqual(layout.memberCenter, CGPoint(x: 60, y: y))
            assertQuickMenuFits(layout, inside: bounds)
        }
    }

    func testQuickNotificationOnlySelectsTheVisibleRoundedButtons() {
        let bounds = CGRect(x: 12, y: 70, width: 366, height: 700)
        for x: CGFloat in [60, 195, 330] {
            let layout = quickMenu(center: CGPoint(x: x, y: 420), bounds: bounds)
            XCTAssertNil(layout.preset(at: layout.memberCenter))
            for preset in MeetingNotificationPreset.allCases {
                let frame = layout.frame(for: preset)
                XCTAssertEqual(layout.preset(at: CGPoint(x: frame.midX, y: frame.midY)), preset)
                // Rounded-off corners and points beyond the button must cancel.
                XCTAssertNil(layout.preset(at: CGPoint(x: frame.minX + 1, y: frame.minY + 1)))
                XCTAssertNil(layout.preset(at: CGPoint(x: frame.maxX + 1, y: frame.midY)))
                XCTAssertNil(layout.preset(at: CGPoint(x: frame.midX, y: frame.maxY + 1)))
            }
            XCTAssertNil(layout.preset(at: CGPoint(x: x, y: 740)))
        }
    }

    @MainActor
    func testQuickNotificationOverlayMatchesWindowCoordinates() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let root = UIViewController()
        root.view.backgroundColor = UIColor(red: 0.77, green: 0.91, blue: 0.96, alpha: 1)
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer {
            MeetingQuickOverlayPresenter.shared.dismiss()
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        let member = UILabel()
        member.text = "멤버 이름"
        member.textAlignment = .center
        member.backgroundColor = .white
        member.layer.cornerRadius = 16
        member.clipsToBounds = true
        root.view.addSubview(member)
        root.view.layoutIfNeeded()

        let bounds = window.bounds.inset(by: window.safeAreaInsets).insetBy(dx: 12, dy: 12)
        let centers = [CGFloat(500), bounds.maxY - 94, bounds.maxY - 80].flatMap { y in
            [CGFloat(60), window.bounds.midX, window.bounds.width - 60].map { CGPoint(x: $0, y: y) }
        }
        for center in centers {
            member.frame = CGRect(x: center.x - 38, y: center.y - 24, width: 76, height: 48)
            let anchor = member.convert(member.bounds, to: window)
            let layout = MeetingQuickMenuLayout(anchor: anchor, availableBounds: bounds)
            let presenter = MeetingQuickOverlayPresenter.shared
            presenter.present(in: window, anchor: anchor, recipientName: "멤버 이름")
            try await Task.sleep(nanoseconds: 150_000_000)
            root.view.layoutIfNeeded()
            XCTAssertEqual(layout.memberCenter, member.center)
            for preset in MeetingNotificationPreset.allCases {
                let button = layout.frame(for: preset)
                XCTAssertEqual(presenter.preset(at: CGPoint(x: button.midX, y: button.midY)), preset)
                XCTAssertNil(presenter.preset(at: CGPoint(x: button.maxX + 1, y: button.midY)))
            }
            XCTAssertNil(presenter.preset(at: member.center))
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            let attachment = XCTAttachment(image: image)
            attachment.name = "멤버 중심 x=\(Int(center.x)) y=\(Int(center.y))"
            attachment.lifetime = .keepAlways
            add(attachment)
            presenter.dismiss()
        }
    }

    private func quickMenu(center: CGPoint, bounds: CGRect) -> MeetingQuickMenuLayout {
        MeetingQuickMenuLayout(anchor: CGRect(x: center.x - 38, y: center.y - 24, width: 76, height: 48), availableBounds: bounds)
    }

    private func assertQuickMenuFits(_ layout: MeetingQuickMenuLayout, inside bounds: CGRect,
                                    file: StaticString = #filePath, line: UInt = #line) {
        let presets = MeetingNotificationPreset.allCases
        let member = CGRect(x: layout.memberCenter.x - MeetingQuickMenuLayout.memberSize.width / 2,
                            y: layout.memberCenter.y - MeetingQuickMenuLayout.memberSize.height / 2,
                            width: MeetingQuickMenuLayout.memberSize.width, height: MeetingQuickMenuLayout.memberSize.height)
        for (index, preset) in presets.enumerated() {
            let frame = layout.frame(for: preset)
            XCTAssertTrue(bounds.contains(frame), "Button \(preset) outside \(bounds): \(frame)", file: file, line: line)
            XCTAssertFalse(frame.intersects(member), "Action overlaps member", file: file, line: line)
            for other in presets.dropFirst(index + 1) {
                XCTAssertFalse(frame.intersects(layout.frame(for: other)), "Actions overlap", file: file, line: line)
            }
        }
    }

}

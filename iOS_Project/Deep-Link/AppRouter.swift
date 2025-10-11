//
//  AppRouter.swift
//  iOS_Project
//
//  Created by CHOI on 10/7/25.
//

import Foundation
import Combine

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    // 탭 전환용
    @Published var selectedTabIndex: Int = AppTabIndex.meeting.rawValue

    // 탭 루트가 소비할 1회성 딥링크 이벤트
    @Published var pendingRoute: DeepLinkDestination?

    private init() {}

    // 알림/딥링크가 들어왔을 때 호출
    func handle(_ dest: DeepLinkDestination) {
        selectedTabIndex = tabIndex(for: dest)
        pendingRoute = dest
    }

    // 화면에서 처리 완료 후 호출 (이벤트 1회성 소비)
    func consume(_ dest: DeepLinkDestination) {
        if pendingRoute == dest {
            pendingRoute = nil
        }
    }

    // MARK: - 딥링크 목적지에 따른 탭 전환 로직

    private func tabIndex(for dest: DeepLinkDestination) -> Int {
        switch dest {
        case .friendRequests:
            return AppTabIndex.friend.rawValue
        case .meetingRequests, .meeting:
            return AppTabIndex.meeting.rawValue
        }
    }
}

//
//  NotificationPayloadParser.swift
//  iOS_Project
//
//  Created by CHOI on 10/7/25.
//

import Foundation

/// FCM 푸시 payload → 딥링크 목적지 변환 유틸
struct NotificationPayloadParser {
    /// userInfo에서 DeepLinkDestination 추출
    static func parseDestination(from userInfo: [AnyHashable: Any]) -> DeepLinkDestination? {
        guard let route = (userInfo["route"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return nil
        }
        switch route {
        case "friendRequests":
            return .friendRequests
        case "meetingRequests":
            return .meetingRequests
        case "meetingView":
            // TODO: MeetingView 딥링크
            return nil
        default:
            return nil
        }
    }
}

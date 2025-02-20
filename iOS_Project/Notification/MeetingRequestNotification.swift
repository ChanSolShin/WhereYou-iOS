// MeetingRequestNotification.swift
// iOS_Project
//
// Created by 신찬솔 on 2/20/25.

import Firebase

class MeetingRequestNotification {
    
    static func sendMeetingRequest(toUserID: String, meetingID: String, meetingName: String, viewModel: MeetingViewModel) {
        // 모임 초대 요청을 보내는 ViewModel의 함수 호출
        viewModel.sendMeetingRequest(toUserIDs: [toUserID], meetingName: meetingName, fromUserID: viewModel.getCurrentUserID() ?? "", fromUserName: "")
        
        // 푸시 알림 전송
        viewModel.getCurrentUserName { userName in
            sendPushNotification(toUserID: toUserID, fromUserName: userName, meetingName: meetingName)
        }
    }
    
    private static func sendPushNotification(toUserID: String, fromUserName: String, meetingName: String) {
        // 푸시 알림 전송 로직
        print("푸시 알림 전송: \(fromUserName)님이 '\(meetingName)' 모임에 초대했습니다.")
        
        // 여기에 Firebase Cloud Functions 호출하거나, 푸시 알림을 전송하는 로직을 구현
        // 예시: FirebaseMessaging 등을 사용하여 푸시 알림을 전송할 수 있습니다.
    }
}

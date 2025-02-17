//
//  FriendRequestNotification.swift
//  iOS_Project
//
//  Created by 신찬솔 on 2/18/25.
//

import Firebase

class FriendRequestNotification {

    static func sendFriendRequest(toEmail email: String, viewModel: FriendListViewModel) {
        // 친구 요청을 보내는 ViewModel의 함수 호출
        viewModel.sendFriendRequest(toEmail: email)
        
        if let userName = viewModel.currentUserName {
            sendPushNotification(toUserID: viewModel.getCurrentUserID() ?? "", fromUserName: userName)
        }
    }
    
    private static func sendPushNotification(toUserID: String, fromUserName: String) {
        // 여기에 푸시 알림 전송 로직 추가
        print("푸시 알림 전송: \(fromUserName)님이 친구 요청을 보냈습니다.")
    }
}

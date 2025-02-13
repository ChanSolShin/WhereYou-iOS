//
//  NotificationManager.swift
//  iOS_Project
//
//  Created by 신찬솔 on 2/13/25.
//

import Foundation
import UserNotifications
import FirebaseFirestore

class NotificationManager {
    
    static let shared = NotificationManager()
    
    private let db = Firestore.firestore()
    
    private init() {}
    
    // 알림 권한 요청
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("알림 권한 요청 실패: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            completion(granted)
        }
    }
    
    // 친구 요청을 감지하고 알림 보내기
    func observeFriendRequests() {
        db.collection("friendsRequests")
            .whereField("status", isEqualTo: "pending") // 상태가 'pending'인 요청만 감지
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    print("친구 요청 리스너 실패: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    return
                }
                
                for document in documents {
                    let data = document.data()
                    if let fromUserID = data["fromUserID"] as? String,
                       let fromUserName = data["fromUserName"] as? String,
                       let toUserID = data["toUserID"] as? String {
                        
                        // 친구 요청을 받은 사람에게 알림을 보냄
                        self.sendNotification(toUserID: toUserID, fromUserName: fromUserName)
                    }
                }
            }
    }
    
    // 알림 보내기
    private func sendNotification(toUserID: String, fromUserName: String) {
        // toUserID를 기준으로 알림을 보내는 방법을 구현
        let content = UNMutableNotificationContent()
        content.title = "친구 요청"
        content.body = "\(fromUserName)님이 친구 요청을 보냈습니다."
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("알림 등록 실패: \(error.localizedDescription)")
            }
        }
    }
}

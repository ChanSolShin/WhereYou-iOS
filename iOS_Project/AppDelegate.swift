//
//  AppDelegate.swift
//  iOS_Project
//
//  Created by 신찬솔 on 2/18/25.
//


import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    let gcmMessageIDKey = "gcm.message_id"
    
    // 앱이 실행될 때 호출되는 함수
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase 초기화
        FirebaseApp.configure()
        
        // 푸시 알림 설정
        configurePushNotifications(application)
        
        // 메시징 델리게이트 설정
        Messaging.messaging().delegate = self
        
        return true
    }
    
    // 푸시 알림 설정
    private func configurePushNotifications(_ application: UIApplication) {
        if #available(iOS 10.0, *) {
            // iOS 10 이상에서 푸시 알림 설정
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { _, _ in }
        } else {
            // iOS 9 이하에서 푸시 알림 설정
            let settings: UIUserNotificationSettings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        // 원격 알림 등록
        application.registerForRemoteNotifications()
    }
    
    // 디바이스 토큰을 받았을 때 FCM에 등록하는 함수
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken  // FCM에 APNS 토큰을 전달
    }
}

// FCM 토큰 및 메시지 관련 처리
extension AppDelegate: MessagingDelegate {
    
    // FCM 토큰을 받았을 때 호출되는 함수
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken {
            print("FCM 토큰: \(fcmToken)")
            // 받은 토큰을 Firebase Firestore에 저장하거나 서버로 전송하는 등의 작업을 함
            
            let dataDict: [String: String] = ["token": fcmToken]
            // 여기서 Firestore에 저장하는 작업을 할 수 있음
        }
    }
}

// 푸시 알림을 앱에서 처리하는 부분
@available(iOS 10, *)
extension AppDelegate: UNUserNotificationCenterDelegate {
  
    // 푸시 알림이 앱이 실행 중일 때 도달하면 호출되는 함수
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        let userInfo = notification.request.content.userInfo
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")  // 메시지 ID를 출력하여 디버깅에 활용
        }
        
        print("Received notification: \(userInfo)")  // 푸시 알림 데이터 출력
        
        // 배지, 소리, 배너 표시 설정
        completionHandler([[.banner, .badge, .sound]])
    }

    // 푸시 알림을 클릭했을 때 호출되는 함수
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo

        // Do Something With MSG Data...
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        print("User Info: \(userInfo)")
        
        completionHandler()
    }
}

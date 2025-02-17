//
//  LoginViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Foundation
import Combine
import FirebaseAuth
import FirebaseMessaging
import FirebaseFirestore

class LoginViewModel: ObservableObject {
    @Published var user: SignUpUserModel = SignUpUserModel(username: "", password: "")
    @Published var isLoggedIn: Bool = false
    @Published var loginErrorMessage: String?
    
    private var db = Firestore.firestore()

    init() {
        checkAutoLogin()
    }
    
    // 이메일 유효성 검사
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: user.username)
    }
    
    // 비밀번호가 비어 있는지 확인
    var isPasswordEmpty: Bool {
        return user.password.isEmpty
    }
    
    // Firebase 로그인 로직
    func login() {
        Auth.auth().signIn(withEmail: user.username, password: user.password) { [weak self] authResult, error in
            // 로그인 성공 시
            if let error = error {
                self?.loginErrorMessage = error.localizedDescription // 로그인 실패 시 오류 메시지 설정
                self?.isLoggedIn = false
                return
            }
            
            // 로그인 성공 시, FCM 토큰 저장
            self?.getFCMToken { fcmToken in
                if let fcmToken = fcmToken {
                    self?.saveFCMTokenToFirestore(fcmToken: fcmToken)
                }
            }
            
            self?.isLoggedIn = true
            self?.loginErrorMessage = nil
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
        }
    }
    
    // FCM 토큰 가져오기
    private func getFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 가져오기 오류: \(error.localizedDescription)")
                completion(nil)
            } else if let token = token {
                print("FCM 토큰: \(token)")
                completion(token)
            } else {
                print("FCM 토큰을 받을 수 없습니다.")
                completion(nil)
            }
        }
    }
    
    // Firestore에 FCM 토큰 저장
    private func saveFCMTokenToFirestore(fcmToken: String) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).updateData([
            "fcmToken": fcmToken
        ]) { [weak self] error in
            if let error = error {
                print("FCM 토큰 저장 오류: \(error.localizedDescription)")
            } else {
                print("FCM 토큰 저장 성공")
            }
        }
    }
    
    // 앱 시작 시 자동 로그인 상태 확인
    private func checkAutoLogin() {
        if Auth.auth().currentUser != nil || UserDefaults.standard.bool(forKey: "isLoggedIn") {
            self.isLoggedIn = true
        } else {
            self.isLoggedIn = false
        }
    }
}

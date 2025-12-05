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
import FirebaseFirestore
import FirebaseMessaging  // FCM 토큰 기능 추가

// Alert 타입 enum -> 강제로그아웃 or 중복로그인 알림 case 구분
enum LoginAlert: Identifiable {
    var id: Int {
        switch self {
        case .forcedLogout: return 0
        case .newDeviceLogin: return 1
        }
    }
    case forcedLogout
    case newDeviceLogin
}

class LoginViewModel: ObservableObject {
    @Published var user: SignUpUserModel = SignUpUserModel(username: "", password: "")
    @Published var isLoggedIn: Bool = false
    @Published var loginErrorMessage: String?
    // 기존 forcedLogout, showNewDeviceLoginAlert -> 하나로 통합
    @Published var currentAlert: LoginAlert?
    
    private let db = Firestore.firestore()
    private var logoutListener: ListenerRegistration?
    private var pendingUserRef: DocumentReference?  // 새 기기 로그인을 위한 임시 Firestore 참조
    
    // 현재 기기의 고유 ID
    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
    
    // 강제 로그아웃 관련 snapshot 무시 기한 (그레이스 기간)
    private var ignoreForcedLogoutUntil: Date?
    
    init() {
        checkAutoLogin()
        
        NotificationCenter.default.addObserver(forName: Notification.Name("UserDidLogout"), object: nil, queue: .main) { [weak self] _ in
            self?.signOut(updateFirestore: false)
        }
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
            print("로그인 시도")
            guard let self = self else { return }
            
            if let error = error {
                self.loginErrorMessage = error.localizedDescription // 로그인 실패 시 오류 메시지 설정
                self.isLoggedIn = false
                return
            }
            
            // 로그인 성공 시, FCM 토큰 저장 후, Firestore 업데이트 전 기기 중복 여부 확인
            guard let uid = authResult?.user.uid else { return }
            let userRef = self.db.collection("users").document(uid)
            self.pendingUserRef = userRef
            userRef.getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let existingDeviceID = data["deviceID"] as? String,
                   existingDeviceID != self.deviceID {
                    // 기존 기기와 deviceID가 다르면 새 기기 로그인 확인 알림 표시
                    DispatchQueue.main.async {
                        self.currentAlert = .newDeviceLogin
                    }
                } else {
                    // FCM 토큰 저장
                    self.getFCMToken { fcmToken in
                        if let token = fcmToken {
                            self.saveFCMTokenToFirestore(fcmToken: token)
                        }
                    }
                    // 기존 기기 로그인 없음 -> Firestore 업데이트 후 로그인 처리
                    userRef.setData([
                        "loginStatus": true,
                        "deviceID": self.deviceID,
                        "lastLogin": Timestamp(date: Date()),
                    ], merge: true) { error in
                        if let error = error {
                            print("Firestore 업데이트 에러: \(error.localizedDescription)")
                        }
                    }
                    DispatchQueue.main.async {
                        self.isLoggedIn = true
                        self.loginErrorMessage = nil
                        UserDefaults.standard.set(true, forKey: "isLoggedIn")
                    }
                    self.startListeningForForcedLogout(uid: uid)
                }
            }
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
        ]) { error in
            if let error = error {
                print("FCM 토큰 저장 오류: \(error.localizedDescription)")
            } else {
                print("FCM 토큰 저장 성공")
            }
        }
    }
    
    // 새로운 기기 로그인 확인 후 호출되는 함수
    func confirmNewDeviceLogin() {
        guard let userRef = pendingUserRef,
              let uid = Auth.auth().currentUser?.uid else { return }
        
        // 새 기기 로그인 확정 후, 강제 로그아웃 처리 무시(그레이스) 기간 설정 -> 2초
        ignoreForcedLogoutUntil = Date().addingTimeInterval(2)
        
        // 기존 listener 제거
        logoutListener?.remove()
        logoutListener = nil
        
        // 강제 로그아웃 처리 후 새 기기 로그인 처리
        userRef.updateData([
            "loginStatus": false,
            "deviceID": FieldValue.delete(),
            "fcmToken": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("기존 세션 강제 로그아웃 처리 에러: \(error.localizedDescription)")
                return
            }
            // 0.5초 딜레이 후 새 기기 로그인 정보 업데이트
            self.getFCMToken { newToken in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    userRef.setData([
                        "loginStatus": true,
                        "deviceID": self.deviceID,
                        "lastLogin": Timestamp(date: Date()),
                        "fcmToken": newToken ?? ""
                    ], merge: true) { error in
                        if let error = error {
                            print("Firestore 업데이트 에러: \(error.localizedDescription)")
                        }
                        DispatchQueue.main.async {
                            self.isLoggedIn = true
                            self.loginErrorMessage = nil
                            UserDefaults.standard.set(true, forKey: "isLoggedIn")
                            self.currentAlert = nil
                        }
                        self.pendingUserRef = nil
                        self.startListeningForForcedLogout(uid: uid)
                    }
                }
            }
        }
    }
    
    // 사용자가 새 기기 로그인 시 강제 로그아웃 확인 알림에서 "취소"를 선택한 경우
    func cancelNewDeviceLogin() {
        self.pendingUserRef = nil
        do {
            try Auth.auth().signOut()
            DispatchQueue.main.async {
                self.isLoggedIn = false
                self.currentAlert = nil
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
            }
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }
    
    // 앱 시작 시 자동 로그인 상태 확인
    private func checkAutoLogin() {
        if Auth.auth().currentUser != nil || UserDefaults.standard.bool(forKey: "isLoggedIn") {
            self.isLoggedIn = true
            if let uid = Auth.auth().currentUser?.uid {
                self.startListeningForForcedLogout(uid: uid)
            }
        } else {
            self.isLoggedIn = false
        }
    }
    
    // Firestore 문서 변경 감지 -> 다른 기기에서 로그인 시 강제 로그아웃 처리
    func startListeningForForcedLogout(uid: String? = nil) {
        let uidToUse: String
        if let uid = uid {
            uidToUse = uid
        } else {
            guard let currentUID = Auth.auth().currentUser?.uid else { return }
            uidToUse = currentUID
        }
        let userRef = db.collection("users").document(uidToUse)
        logoutListener?.remove()
        logoutListener = userRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            
            // 그레이스 기간 내라면 강제 로그아웃 체크를 무시
            if let ignoreUntil = self.ignoreForcedLogoutUntil, Date() < ignoreUntil {
                return
            }
            
            let remoteDeviceID = data["deviceID"] as? String ?? ""
            if remoteDeviceID != self.deviceID {
                DispatchQueue.main.async {
                    self.currentAlert = .forcedLogout
                    // Firestore 업데이트 없이 로컬에서만 로그아웃 처리
                    self.signOut(updateFirestore: false)
                }
            }
        }
    }
    
    // 로그아웃 처리
    func signOut(updateFirestore: Bool = true) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isLoggedIn = false
            return
        }
        
        if updateFirestore {
            let userRef = db.collection("users").document(uid)
            userRef.updateData([
                "loginStatus": false,
                "deviceID": FieldValue.delete(),
                "fcmToken": FieldValue.delete() // FCM 토큰 삭제
            ]) { error in
                if let error = error {
                    print("Error updating login status: \(error.localizedDescription)")
                }
                do {
                    try Auth.auth().signOut()
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    DispatchQueue.main.async {
                        self.isLoggedIn = false
                    }
                } catch let signOutError as NSError {
                    print("Error signing out: \(signOutError.localizedDescription)")
                }
            }
        } else {
            do {
                try Auth.auth().signOut()
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
                DispatchQueue.main.async {
                    self.isLoggedIn = false
                }
            } catch let signOutError as NSError {
                print("Error signing out: \(signOutError.localizedDescription)")
            }
        }
        
        // 리스너 제거
        logoutListener?.remove()
        logoutListener = nil
    }
}

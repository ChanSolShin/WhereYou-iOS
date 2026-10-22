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
        case .loginFailed: return 2
        }
    }
    case forcedLogout
    case newDeviceLogin
    case loginFailed(String)
}

class LoginViewModel: ObservableObject {
    @Published var user: SignUpUserModel = SignUpUserModel(username: "", password: "")
    @Published var isLoggedIn: Bool = false
    @Published var isLoggingIn: Bool = false
    // 기존 forcedLogout, showNewDeviceLoginAlert -> 하나로 통합
    @Published var currentAlert: LoginAlert?
    
    private let db = Firestore.firestore()
    private var logoutListener: ListenerRegistration?
    private var pendingUserRef: DocumentReference?  // 새 기기 로그인을 위한 임시 Firestore 참조
    private var loginAttemptID: UUID?
    
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
        guard !isLoggingIn else { return }
        let email = user.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, !user.password.isEmpty else {
            currentAlert = .loginFailed("이메일과 비밀번호를 입력해주세요.")
            return
        }

        isLoggingIn = true
        currentAlert = nil
        let attemptID = beginLoginAttempt()
        Auth.auth().signIn(withEmail: email, password: user.password) { [weak self] authResult, error in
            DispatchQueue.main.async {
                guard let self = self, self.loginAttemptID == attemptID else { return }
                if let error = error {
                    print("[Login] Authentication failed (code: \((error as NSError).code))")
                    self.failLogin(self.messageForAuthenticationError(error))
                    return
                }
                guard let uid = authResult?.user.uid else {
                    self.failLogin("로그인 정보를 확인하지 못했습니다. 다시 시도해주세요.")
                    return
                }

                let userRef = self.db.collection("users").document(uid)
                print("[Login] Authentication succeeded; loading user document")
                userRef.getDocument { [weak self] snapshot, error in
                    DispatchQueue.main.async {
                        guard let self = self, self.loginAttemptID == attemptID else { return }
                        if let error = error {
                            print("[Login] User document read failed (code: \((error as NSError).code))")
                            self.failLogin("사용자 정보를 불러오지 못했습니다. 네트워크 연결을 확인하고 다시 시도해주세요. (\(error.localizedDescription))")
                            return
                        }
                        guard let data = snapshot?.data() else {
                            print("[Login] User document missing")
                            self.failLogin("사용자 정보가 없습니다. 고객센터에 문의해주세요.")
                            return
                        }
                        print("[Login] User document loaded")
                        self.pendingUserRef = userRef
                        if let existingDeviceID = data["deviceID"] as? String,
                           existingDeviceID != self.deviceID {
                            self.loginAttemptID = nil
                            self.isLoggingIn = false
                            self.currentAlert = .newDeviceLogin
                            return
                        }

                        userRef.setData([
                            "loginStatus": true,
                            "deviceID": self.deviceID,
                            "lastLogin": Timestamp(date: Date())
                        ], merge: true) { [weak self] error in
                            DispatchQueue.main.async {
                                guard let self = self, self.loginAttemptID == attemptID else { return }
                                if let error = error {
                                    print("[Login] Login state write failed (code: \((error as NSError).code))")
                                    self.failLogin("로그인 상태를 저장하지 못했습니다. 다시 시도해주세요. (\(error.localizedDescription))")
                                    return
                                }
                                print("[Login] Login state saved")
                                self.loginAttemptID = nil
                                self.isLoggingIn = false
                                self.isLoggedIn = true
                                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                                self.startListeningForForcedLogout(uid: uid)
                                self.getFCMToken { token in
                                    if let token = token { self.saveFCMTokenToFirestore(fcmToken: token) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func failLogin(_ message: String) {
        loginAttemptID = nil
        isLoggingIn = false
        currentAlert = .loginFailed(message)
    }

    private func beginLoginAttempt() -> UUID {
        let attemptID = UUID()
        loginAttemptID = attemptID
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { [weak self] in
            guard let self = self, self.loginAttemptID == attemptID else { return }
            print("[Login] Login attempt timed out")
            self.failLogin("로그인 응답이 지연되고 있습니다. 네트워크 연결을 확인하고 다시 시도해주세요.")
        }
        return attemptID
    }

    private func messageForAuthenticationError(_ error: Error) -> String {
        guard (error as NSError).domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return "로그인에 실패했습니다. 잠시 후 다시 시도해주세요. (\(error.localizedDescription))"
        }
        switch code {
        case .invalidCredential, .wrongPassword, .userNotFound:
            return "이메일 또는 비밀번호를 확인해주세요."
        case .invalidEmail:
            return "올바른 이메일 주소를 입력해주세요."
        case .networkError:
            return "네트워크 연결을 확인하고 다시 시도해주세요."
        case .tooManyRequests:
            return "로그인 시도가 많습니다. 잠시 후 다시 시도해주세요."
        case .userDisabled:
            return "사용할 수 없는 계정입니다. 고객센터에 문의해주세요."
        default:
            return "로그인에 실패했습니다. 잠시 후 다시 시도해주세요. (\(error.localizedDescription))"
        }
    }
    
    // FCM 토큰 가져오기
    private func getFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 가져오기 오류: \(error.localizedDescription)")
                completion(nil)
            } else if let token = token {
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
        isLoggingIn = true
        let attemptID = beginLoginAttempt()
        
        // 새 기기 로그인 확정 후, 강제 로그아웃 처리 무시(그레이스) 기간 설정 -> 2초
        ignoreForcedLogoutUntil = Date().addingTimeInterval(2)
        
        // 기존 listener 제거
        logoutListener?.remove()
        logoutListener = nil
        
        // 기기 ID를 한 번에 바꾸면 기존 기기는 리스너에서 로그아웃하고,
        // 현재 기기는 중간 상태를 거치지 않는다.
        userRef.setData([
            "loginStatus": true,
            "deviceID": deviceID,
            "lastLogin": Timestamp(date: Date()),
            "fcmToken": FieldValue.delete()
        ], merge: true) { [weak self] error in
            DispatchQueue.main.async {
                guard let self = self, self.loginAttemptID == attemptID else { return }
                if let error = error {
                    self.failLogin("기기 전환에 실패했습니다. 다시 시도해주세요. (\(error.localizedDescription))")
                    return
                }
                self.loginAttemptID = nil
                self.isLoggingIn = false
                self.isLoggedIn = true
                self.currentAlert = nil
                self.pendingUserRef = nil
                UserDefaults.standard.set(true, forKey: "isLoggedIn")
                self.startListeningForForcedLogout(uid: uid)
                self.getFCMToken { token in
                    if let token = token { self.saveFCMTokenToFirestore(fcmToken: token) }
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
        if Auth.auth().currentUser != nil {
            self.isLoggedIn = true
            if let uid = Auth.auth().currentUser?.uid {
                self.startListeningForForcedLogout(uid: uid)
            }
        } else {
            self.isLoggedIn = false
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
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

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

// 인증 상태별 화면 분기
enum AuthState: Equatable {
    case checking       // 앱 시작 시 사용자 문서 확인 중
    case checkFailed    // 사용자 문서 확인 실패 (재시도 필요)
    case loggedOut
    case needsProfile   // 소셜 최초 로그인 후 회원정보 미입력
    case loggedIn
}

class LoginViewModel: ObservableObject {
    @Published var user: SignUpUserModel = SignUpUserModel(username: "", password: "")
    @Published var authState: AuthState = .checking
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
        guard !ChatKeyboardUITest.isEnabled else { return }
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

                print("[Login] Authentication succeeded; loading user document")
                self.establishSession(uid: uid, attemptID: attemptID)
            }
        }
    }

    // 소셜 로그인 (Google/Apple)
    func socialLogin(with provider: SocialAuthProvider) {
        guard !isLoggingIn else { return }
        isLoggingIn = true
        currentAlert = nil
        Task { @MainActor [weak self] in
            do {
                let result = try await SocialAuthManager.signIn(with: provider)
                guard let self = self else { return }
                // 소셜 로그인 창 입력 시간이 있어 인증 완료 후부터 시간 제한 적용
                let attemptID = self.beginLoginAttempt()
                if result.isNewUser {
                    self.registerTempSocialUser(uid: result.user.uid, provider: provider)
                }
                print("[Login] Social authentication succeeded; loading user document")
                self.establishSession(uid: result.user.uid, attemptID: attemptID, allowsProfileSetup: true)
            } catch SocialAuthError.canceled {
                self?.isLoggingIn = false
            } catch {
                print("[Login] Social authentication failed (code: \((error as NSError).code))")
                self?.failLogin(Self.messageForSocialAuthError(error))
            }
        }
    }

    // 회원정보 입력 전 이탈한 소셜 계정 정리용 (Functions에서 일정 시간 후 삭제)
    private func registerTempSocialUser(uid: String, provider: SocialAuthProvider) {
        db.collection("tempUsers").document(uid).setData([
            "uid": uid,
            "createdAt": Timestamp(date: Date()),
            "linked": false,
            "provider": provider.providerID
        ]) { error in
            if let error = error {
                print("[Login] Temp social user save failed (code: \((error as NSError).code))")
            }
        }
    }

    private static func messageForSocialAuthError(_ error: Error) -> String {
        if let socialError = error as? SocialAuthError {
            return socialError.localizedDescription
        }
        if (error as NSError).domain == AuthErrorDomain,
           let code = AuthErrorCode(rawValue: (error as NSError).code) {
            switch code {
            case .accountExistsWithDifferentCredential:
                return "같은 이메일로 가입된 계정이 있습니다. 기존 로그인 방법으로 로그인해주세요."
            case .networkError:
                return "네트워크 연결을 확인하고 다시 시도해주세요."
            case .userDisabled:
                return "사용할 수 없는 계정입니다. 고객센터에 문의해주세요."
            default:
                break
            }
        }
        return "로그인에 실패했습니다. 잠시 후 다시 시도해주세요. (\(error.localizedDescription))"
    }

    // Firebase 인증 이후 공통 세션 처리
    // 이메일/소셜 로그인 모두 인증 성공 후 호출
    // allowsProfileSetup: 사용자 문서가 없으면 회원정보 입력으로 이동 (소셜 최초 로그인)
    private func establishSession(uid: String, attemptID: UUID, allowsProfileSetup: Bool = false) {
        let userRef = db.collection("users").document(uid)
        userRef.getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                guard let self = self, self.loginAttemptID == attemptID else { return }
                if let error = error {
                    print("[Login] User document read failed (code: \((error as NSError).code))")
                    self.failLogin("사용자 정보를 불러오지 못했습니다. 네트워크 연결을 확인하고 다시 시도해주세요. (\(error.localizedDescription))")
                    return
                }
                guard let data = snapshot?.data() else {
                    if allowsProfileSetup {
                        print("[Login] User document missing; profile setup required")
                        self.loginAttemptID = nil
                        self.isLoggingIn = false
                        self.authState = .needsProfile
                        return
                    }
                    print("[Login] User document missing")
                    self.failLogin("사용자 정보가 없습니다. 고객센터에 문의해주세요.")
                    return
                }
                print("[Login] User document loaded")
                if let user = Auth.auth().currentUser {
                    UserAuthInfo.syncIfNeeded(user: user, existing: data)
                }
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
                        self.completeLogin(uid: uid)
                    }
                }
            }
        }
    }

    // 로그인 확정 후 공통 처리 (상태 반영, 강제 로그아웃 리스너, FCM 토큰 동기화)
    private func completeLogin(uid: String) {
        loginAttemptID = nil
        isLoggingIn = false
        authState = .loggedIn
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        startListeningForForcedLogout(uid: uid)
        PushTokenManager.syncCurrentToken()
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
                self.currentAlert = nil
                self.pendingUserRef = nil
                self.completeLogin(uid: uid)
            }
        }
    }
    
    // 사용자가 새 기기 로그인 시 강제 로그아웃 확인 알림에서 "취소"를 선택한 경우
    func cancelNewDeviceLogin() {
        self.pendingUserRef = nil
        do {
            try Auth.auth().signOut()
            GoogleAuthService.signOut()
            DispatchQueue.main.async {
                self.authState = .loggedOut
                self.currentAlert = nil
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
            }
        } catch let signOutError as NSError {
            print("Error signing out: \(signOutError.localizedDescription)")
        }
    }

    // 앱 시작 시 자동 로그인 상태 확인
    // 사용자 문서 유무로 메인 / 로그아웃 분기
    private func checkAutoLogin() {
        guard let currentUser = Auth.auth().currentUser else {
            authState = .loggedOut
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            return
        }

        authState = .checking
        let uid = currentUser.uid
        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            DispatchQueue.main.async {
                // 확인 중 로그아웃 등으로 사용자가 바뀐 경우 무시
                guard let self = self, Auth.auth().currentUser?.uid == uid else { return }
                if let error = error {
                    print("[Login] Auto login check failed (code: \((error as NSError).code))")
                    self.authState = .checkFailed
                    return
                }
                if let data = snapshot?.data() {
                    self.authState = .loggedIn
                    self.startListeningForForcedLogout(uid: uid)
                    // 로그인 유지 중인 기존 유저도 providers, loginEmail backfill
                    UserAuthInfo.syncIfNeeded(user: currentUser, existing: data)
                } else {
                    // 가입 도중 이탈한 임시 계정 (이메일/소셜 공통): 서버에서 삭제 후 로그인 화면부터 다시 시작
                    TempAccountService.discard { [weak self] in
                        self?.signOut(updateFirestore: false)
                    }
                }
            }
        }
    }

    // 사용자 문서 확인 실패 시 재시도
    func retryAutoLoginCheck() {
        checkAutoLogin()
    }

    // 소셜 회원정보 입력 완료 후 세션 확립 (메인 이동)
    func completeSocialSignUp() {
        guard let uid = Auth.auth().currentUser?.uid else {
            signOut(updateFirestore: false)
            return
        }
        isLoggingIn = true
        currentAlert = nil
        let attemptID = beginLoginAttempt()
        establishSession(uid: uid, attemptID: attemptID)
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
            self.authState = .loggedOut
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
                    GoogleAuthService.signOut()
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    DispatchQueue.main.async {
                        self.authState = .loggedOut
                    }
                } catch let signOutError as NSError {
                    print("Error signing out: \(signOutError.localizedDescription)")
                }
            }
        } else {
            do {
                try Auth.auth().signOut()
                GoogleAuthService.signOut()
                UserDefaults.standard.set(false, forKey: "isLoggedIn")
                DispatchQueue.main.async {
                    self.authState = .loggedOut
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

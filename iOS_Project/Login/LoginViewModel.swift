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
    @Published var currentAlert: LoginAlert?
    
    private let db = Firestore.firestore()
    private var logoutListener: ListenerRegistration?
    private var pendingUserRef: DocumentReference?
    
    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
    private var ignoreForcedLogoutUntil: Date?
    
    init() {
        checkAutoLogin()
    }
    
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: user.username)
    }
    
    var isPasswordEmpty: Bool {
        return user.password.isEmpty
    }
    
    func login() {
        Auth.auth().signIn(withEmail: user.username, password: user.password) { [weak self] authResult, error in
            guard let self = self else { return }
            
            if let error = error {
                self.loginErrorMessage = error.localizedDescription
                self.isLoggedIn = false
                return
            }
            
            guard let uid = authResult?.user.uid else { return }
            let userRef = self.db.collection("users").document(uid)
            self.pendingUserRef = userRef
            
            userRef.getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let existingDeviceID = data["deviceID"] as? String,
                   existingDeviceID != self.deviceID {
                    DispatchQueue.main.async {
                        self.currentAlert = .newDeviceLogin
                    }
                } else {
                    self.getFCMToken { fcmToken in
                        var updatedData: [String: Any] = [
                            "loginStatus": true,
                            "deviceID": self.deviceID,
                            "lastLogin": Timestamp(date: Date())
                        ]
                        if let token = fcmToken {
                            updatedData["fcmToken"] = token
                        }

                        userRef.setData(updatedData, merge: true) { error in
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
    }
    
    private func getFCMToken(completion: @escaping (String?) -> Void) {
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM 토큰 가져오기 오류: \(error.localizedDescription)")
                completion(nil)
            } else {
                completion(token)
            }
        }
    }
    
    func confirmNewDeviceLogin() {
        guard let userRef = pendingUserRef,
              let uid = Auth.auth().currentUser?.uid else { return }
        
        ignoreForcedLogoutUntil = Date().addingTimeInterval(2)
        logoutListener?.remove()
        logoutListener = nil
        
        userRef.updateData([
            "loginStatus": false,
            "deviceID": FieldValue.delete(),
            "fcmToken": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("기존 세션 강제 로그아웃 처리 에러: \(error.localizedDescription)")
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.getFCMToken { fcmToken in
                    var newUserData: [String: Any] = [
                        "loginStatus": true,
                        "deviceID": self.deviceID,
                        "lastLogin": Timestamp(date: Date())
                    ]
                    if let token = fcmToken {
                        newUserData["fcmToken"] = token
                    }

                    userRef.setData(newUserData, merge: true) { error in
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
    
    func startListeningForForcedLogout(uid: String? = nil) {
        let uidToUse = uid ?? Auth.auth().currentUser?.uid ?? ""
        let userRef = db.collection("users").document(uidToUse)
        
        logoutListener?.remove()
        logoutListener = userRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            
            if let ignoreUntil = self.ignoreForcedLogoutUntil, Date() < ignoreUntil {
                return
            }
            
            let remoteDeviceID = data["deviceID"] as? String ?? ""
            if remoteDeviceID != self.deviceID {
                DispatchQueue.main.async {
                    self.currentAlert = .forcedLogout
                    self.signOut(updateFirestore: false)
                }
            }
        }
    }
    
    func signOut(updateFirestore: Bool = true) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isLoggedIn = false
            return
        }
        
        if updateFirestore {
            db.collection("users").document(uid).updateData([
                "loginStatus": false,
                "deviceID": FieldValue.delete(),
                "fcmToken": FieldValue.delete()
            ]) { _ in
                self.performSignOut()
            }
        } else {
            self.performSignOut()
        }
    }
    
    private func performSignOut() {
        do {
            try Auth.auth().signOut()
            UserDefaults.standard.set(false, forKey: "isLoggedIn")
            DispatchQueue.main.async {
                self.isLoggedIn = false
            }
        } catch {
            print("로그아웃 실패: \(error.localizedDescription)")
        }
    }
}

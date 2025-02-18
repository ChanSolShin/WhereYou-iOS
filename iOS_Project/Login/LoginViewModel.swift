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

class LoginViewModel: ObservableObject {
    @Published var user: SignUpUserModel = SignUpUserModel(username: "", password: "")
    @Published var isLoggedIn: Bool = false
    @Published var loginErrorMessage: String?
    @Published var forcedLogout: Bool = false  // 강제 로그아웃 발생 시 true로 설정 -> 알림 표시용
    @Published var showNewDeviceLoginAlert: Bool = false

    private let db = Firestore.firestore()
    private var logoutListener: ListenerRegistration?
    private var pendingUserRef: DocumentReference?

    // 현재 기기의 고유 ID
    private let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
    
    init(){
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
            print("로그인 시도")
            guard let self = self else { return }
            
            if let error = error {
                self.loginErrorMessage = error.localizedDescription // 로그인 실패 시 오류 메시지 설정
                self.isLoggedIn = false
                return
            }
            
            // 로그인 성공 시, Firestore 업데이트 전, 기기 중복 여부 확인
            guard let uid = authResult?.user.uid else { return }
            let userRef = self.db.collection("users").document(uid)
            self.pendingUserRef = userRef  // 임시로 저장
            userRef.getDocument { snapshot, error in
                if let data = snapshot?.data(),
                   let existingDeviceID = data["deviceID"] as? String,
                   existingDeviceID != self.deviceID {
                    // 다른 기기에서 이미 로그인 중 -> 새로운 기기에서 로그인 여부 확인 알림 표시
                    DispatchQueue.main.async {
                        self.showNewDeviceLoginAlert = true
                    }
                } else {
                    // 문제 없으면 바로 Firestore 업데이트 후 로그인 처리
                    userRef.setData([
                        "loginStatus": true,
                        "deviceID": self.deviceID,
                        "lastLogin": Timestamp(date: Date())
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
    
    // 새로운 기기 로그인 확인 후 호출되는 함수
    func confirmNewDeviceLogin() {
        guard let userRef = pendingUserRef,
              let uid = Auth.auth().currentUser?.uid else { return }
        userRef.setData([
            "loginStatus": true,
            "deviceID": self.deviceID,
            "lastLogin": Timestamp(date: Date())
        ], merge: true) { error in
            if let error = error {
                print("Firestore 업데이트 에러: \(error.localizedDescription)")
            }
        }
        DispatchQueue.main.async {
            self.isLoggedIn = true
            self.loginErrorMessage = nil
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            self.showNewDeviceLoginAlert = false
        }
        self.startListeningForForcedLogout(uid: uid)
        self.pendingUserRef = nil
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
        // 기존 리스너 제거
        logoutListener?.remove()
        logoutListener = userRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            let remoteDeviceID = data["deviceID"] as? String ?? ""
            // 다른 기기에서 로그인되어 저장된 deviceID와 다르면 강제 로그아웃 실행
            if remoteDeviceID != self.deviceID {
                DispatchQueue.main.async {
                    self.forcedLogout = true // 강제 로그아웃 알림 표시용 플래그 활성화
                    self.signOut()
                }
            }
        }
    }
    
    // 로그아웃 처리 (Firestore의 loginStatus 필드를 false로 업데이트)
    func signOut() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.isLoggedIn = false
            return
        }
        
        let userRef = db.collection("users").document(uid)
        userRef.updateData([
            "loginStatus": false
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
        
        // 리스너 제거
        logoutListener?.remove()
        logoutListener = nil
    }
}

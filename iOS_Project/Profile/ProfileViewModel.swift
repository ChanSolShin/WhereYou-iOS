//
//  ProfileViewModel.swift
//  iOS_Project
//
//  Created by CHOI on 11/5/24.
//

import Foundation
import FirebaseFirestore
import FirebaseDatabase
import FirebaseAuth
import SwiftUI

enum ActiveAlert: Identifiable {
    case delete, validation, back, passwordError
    var id: Int {
        switch self {
        case .delete: return 1
        case .validation: return 2
        case .back: return 3
        case .passwordError: return 4
        }
    }
}

class ProfileViewModel: ObservableObject {
    @Published var profile: ProfileModel?
    @Published var isEditing = false
    @Published var errorMessage: String? // 에러 메시지 상태 추가
    @Published var navigateToLogin = false // 로그인 화면으로 이동 플래그
    @Published var isProcessing = false // 처리 중 상태 추가
    
    @Published var activeAlert: ActiveAlert? = nil
    @Published var showPasswordAlert: Bool = false

    private let db = Firestore.firestore()
    
    init() {
        fetchUserProfile()
    }
    
    // Firestore에서 사용자 프로필 가져오기
    func fetchUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user profile: \(error)")
                return
            }
            if let data = snapshot?.data() {
                let name = data["name"] as? String ?? ""
                let email = data["email"] as? String ?? ""
                let phoneNumber = data["phoneNumber"] as? String ?? ""
                let birthday = data["birthday"] as? String ?? ""
                self.profile = ProfileModel(name: name, email: email, phoneNumber: phoneNumber, birthday: birthday)
            }
        }
    }
    
    // Firestore에서 데이터 업데이트
    func updateProfileData(newName: String, newEmail: String, newPhoneNumber: String, newBirthday: String) -> Bool {
        guard isValidEmail(newEmail) else {
            errorMessage = "유효하지 않은 이메일 형식입니다."
            return false
        }
        
        guard isValidBirthday(newBirthday) else {
            errorMessage = "생년월일은 8자리 숫자로 입력해 주세요."
            return false
        }
        
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        
        db.collection("users").document(uid).updateData([
            "name": newName,
            "email": newEmail,
            "phoneNumber": newPhoneNumber,
            "birthday": newBirthday
        ]) { error in
            if let error = error {
                print("Error updating profile data: \(error)")
            } else {
                self.profile?.name = newName
                self.profile?.email = newEmail
                self.profile?.phoneNumber = newPhoneNumber
                self.profile?.birthday = newBirthday
            }
        }
        return true
    }
    
    // 이메일 유효성 검사
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
    
    // 생일 유효성 검사
    private func isValidBirthday(_ birthday: String) -> Bool {
        return birthday.count == 8 && birthday.allSatisfy { $0.isNumber }
    }
    
    // MARK: - 계정 탈퇴 (재인증 후 진행)
    
    // 재인증 후 계정 삭제 (비밀번호 입력 후 호출)
    func reauthenticateAndDelete(password: String) {
        guard let user = Auth.auth().currentUser, let email = user.email else {
            self.errorMessage = "사용자 정보가 없습니다."
            return
        }
        
        self.isProcessing = true
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { [weak self] result, error in
            if let error = error {
                DispatchQueue.main.async {
                    // 재인증 실패 시, activeAlert를 passwordError로 설정하여 alert 표시
                    self?.activeAlert = .passwordError
                    self?.isProcessing = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self?.showPasswordAlert = true
                    }
                }
                return
            }
            // 재인증 성공 시, 관련 데이터 정리 및 최종 삭제 진행
            self?.performDeletionCleanup()
        }
    }
    
    // 관련 데이터 정리 후 Firestore 사용자 문서와 Auth 계정 삭제
    func performDeletionCleanup() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let group = DispatchGroup()
        var encounteredError: Error?
        
        // friendRequests: 해당 uid 관련 문서 삭제
        for field in ["fromUserID", "toUserID"] {
            group.enter()
            db.collection("friendRequests")
                .whereField(field, isEqualTo: uid)
                .getDocuments { snapshot, error in
                    if let error = error { encounteredError = error; group.leave(); return }
                    let batch = self.db.batch()
                    snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.commit { error in
                        if let error = error { encounteredError = error }
                        group.leave()
                    }
                }
        }
        
        // meetingRequests: 해당 uid 관련 문서 삭제
        for field in ["fromUserID", "toUserID"] {
            group.enter()
            db.collection("meetingRequests")
                .whereField(field, isEqualTo: uid)
                .getDocuments { snapshot, error in
                    if let error = error { encounteredError = error; group.leave(); return }
                    let batch = self.db.batch()
                    snapshot?.documents.forEach { batch.deleteDocument($0.reference) }
                    batch.commit { error in
                        if let error = error { encounteredError = error }
                        group.leave()
                    }
                }
        }
        
        // Firestore meetings: meetingMembers 배열에서 해당 uid 제거
        group.enter()
        db.collection("meetings")
            .whereField("meetingMembers", arrayContains: uid)
            .getDocuments { snapshot, error in
                if let error = error { encounteredError = error; group.leave(); return }
                let batch = self.db.batch()
                snapshot?.documents.forEach { doc in
                    var members = doc.get("meetingMembers") as? [String] ?? []
                    members.removeAll { $0 == uid }
                    batch.updateData(["meetingMembers": members], forDocument: doc.reference)

                    // Check for meetingMaster and delete or update master
                    let master = doc.get("meetingMaster") as? String ?? ""
                    if master == uid {
                        if members.isEmpty {
                            // Delete the whole meeting document if no members left
                            batch.deleteDocument(doc.reference)
                        } else {
                            // Assign new random master
                            let newMaster = members.randomElement() ?? ""
                            batch.updateData(["meetingMaster": newMaster], forDocument: doc.reference)
                        }
                    }
                }
                batch.commit { error in
                    if let error = error { encounteredError = error }
                    group.leave()
                }
            }
        
        // Realtime DB meetings: participants 배열에서 해당 uid 제거
        group.enter()
        let rtdbRef = Database.database().reference().child("meetings")
        rtdbRef.observeSingleEvent(of: .value) { snapshot in
            var updates: [String: Any?] = [:]
            for child in snapshot.children {
                if let meetingSnap = child as? DataSnapshot,
                   var meetingData = meetingSnap.value as? [String: Any],
                   var participants = meetingData["participants"] as? [String],
                   participants.contains(uid) {
                    participants.removeAll { $0 == uid }
                    updates["\(meetingSnap.key)/participants"] = participants
                }
            }
            rtdbRef.updateChildValues(updates) { error, _ in
                if let error = error { encounteredError = error }
                group.leave()
            }
        }
        
        // Firestore users: 다른 사용자의 friends 배열에서 해당 uid 제거
        group.enter()
        db.collection("users")
            .whereField("friends", arrayContains: uid)
            .getDocuments { snapshot, error in
                if let error = error { encounteredError = error; group.leave(); return }
                let batch = self.db.batch()
                snapshot?.documents.forEach { doc in
                    var friends = doc.get("friends") as? [String] ?? []
                    friends.removeAll { $0 == uid }
                    batch.updateData(["friends": friends], forDocument: doc.reference)
                }
                batch.commit { error in
                    if let error = error { encounteredError = error }
                    group.leave()
                }
            }
        
        group.notify(queue: .main) {
            self.isProcessing = false
            if let error = encounteredError {
                self.errorMessage = "계정 삭제 전 오류: \(error.localizedDescription)"
                return
            }
            
            self.db.collection("users").document(uid).delete { [weak self] error in
                if let error = error {
                    self?.errorMessage = "계정 삭제 중 오류: \(error.localizedDescription)"
                    return
                }
                
                user.delete { error in
                    if let error = error {
                        self?.errorMessage = "계정 삭제 중 오류: \(error.localizedDescription)"
                    } else {
                        do { try Auth.auth().signOut() } catch { print("로그아웃 오류: \(error)") }
                        UserDefaults.standard.set(false, forKey: "isLoggedIn")
                        NotificationCenter.default.post(name: Notification.Name("UserDidLogout"), object: nil)
                        self?.navigateToLogin = true
                    }
                }
            }
        }
    }
}

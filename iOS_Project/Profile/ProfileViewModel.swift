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
    case delete, validation, back, passwordError, deleteFailed
    var id: Int {
        switch self {
        case .delete: return 1
        case .validation: return 2
        case .back: return 3
        case .passwordError: return 4
        case .deleteFailed: return 5
        }
    }
}

// 탈퇴 전 재인증 방식
enum WithdrawalReauth {
    case password
    case social(SocialAuthProvider)
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
    
    // 이메일 수정 가능 여부
    // 비밀번호 로그인 계정(통합 계정 포함)은 로그인 이메일로 고정, 소셜 전용 계정만 수정 가능
    var canEditEmail: Bool {
        guard let user = Auth.auth().currentUser else { return false }
        return !user.providerData.contains { $0.providerID == "password" }
    }

    // Firestore에서 데이터 업데이트 (연락처는 수정 불가)
    func updateProfileData(newName: String, newEmail: String, newBirthday: String, completion: @escaping (Bool) -> Void) {
        let trimmedEmail = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        if canEditEmail, !trimmedEmail.isEmpty, !isValidEmail(trimmedEmail) {
            errorMessage = "유효하지 않은 이메일 형식입니다."
            completion(false)
            return
        }

        // 생년월일은 선택 입력, 변환할 수 없는 기존 값은 수정 전까지 그대로 유지
        guard newBirthday.isEmpty || newBirthday == profile?.birthday || BirthdayWheelPicker.date(from: newBirthday) != nil else {
            errorMessage = "생년월일을 다시 선택해 주세요."
            completion(false)
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }

        var updates: [String: Any] = [
            "name": newName,
            "birthday": newBirthday.isEmpty ? FieldValue.delete() : newBirthday
        ]
        if canEditEmail {
            updates["email"] = trimmedEmail.isEmpty ? FieldValue.delete() : trimmedEmail
        }

        let save = { [weak self] in
            self?.db.collection("users").document(uid).updateData(updates) { error in
                self?.isProcessing = false
                if let error = error {
                    print("Error updating profile data: \(error)")
                    self?.errorMessage = "저장하지 못했습니다. 잠시 후 다시 시도해주세요."
                    completion(false)
                    return
                }
                self?.profile?.name = newName
                self?.profile?.birthday = newBirthday
                if self?.canEditEmail == true {
                    self?.profile?.email = trimmedEmail
                }
                completion(true)
            }
        }

        isProcessing = true
        // 이메일을 바꾼 경우만 다른 유저와 중복 검사
        guard canEditEmail, !trimmedEmail.isEmpty, trimmedEmail != profile?.email else {
            save()
            return
        }
        db.collection("users").whereField("email", isEqualTo: trimmedEmail).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("Error checking email: \(error)")
                self?.isProcessing = false
                self?.errorMessage = "이메일 확인 중 오류가 발생했습니다. 다시 시도해주세요."
                completion(false)
                return
            }
            if snapshot?.documents.contains(where: { $0.documentID != uid }) == true {
                self?.isProcessing = false
                self?.errorMessage = "이미 사용 중인 이메일입니다."
                completion(false)
                return
            }
            save()
        }
    }

    // 이메일 유효성 검사
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: email)
    }
    
    // MARK: - 계정 탈퇴 (재인증 후 진행)

    // 연결된 로그인 수단에 따라 재인증 방식 자동 선택
    // Apple 연결 → Apple (토큰 해지에 필요한 인증 코드를 함께 받음), 비밀번호 → 비밀번호 입력, 그 외 → 연결된 소셜
    // TODO: 카카오/네이버 - SocialAuthProvider case 추가 시 소셜 재인증에 포함
    var withdrawalReauth: WithdrawalReauth? {
        guard let user = Auth.auth().currentUser else { return nil }
        let providerIDs = Set(user.providerData.map(\.providerID))
        if providerIDs.contains(SocialAuthProvider.apple.providerID) {
            return .social(.apple)
        }
        if providerIDs.contains("password") {
            return .password
        }
        if let provider = SocialAuthProvider.allCases.first(where: { providerIDs.contains($0.providerID) }) {
            return .social(provider)
        }
        return nil
    }

    // 탈퇴 실패 알림 표시
    func showDeleteFailure(_ message: String) {
        errorMessage = message
        activeAlert = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.activeAlert = .deleteFailed
        }
    }

    // 소셜 재인증 후 계정 삭제 (Apple은 토큰 해지 후 진행, 해지 실패해도 계속)
    @MainActor
    func reauthenticateWithSocialAndDelete(_ provider: SocialAuthProvider) {
        guard let user = Auth.auth().currentUser else {
            showDeleteFailure("사용자 정보가 없습니다. 다시 로그인해주세요.")
            return
        }

        isProcessing = true
        Task { @MainActor in
            do {
                let social = try await SocialAuthManager.reauthenticate(user, with: provider)
                if provider == .apple {
                    await AppleAuthService.revokeToken(authorizationCode: social.authorizationCode)
                }
                performDeletionCleanup()
            } catch SocialAuthError.canceled {
                isProcessing = false
            } catch {
                isProcessing = false
                let code = AuthErrorCode(rawValue: (error as NSError).code)
                print("[Auth] Withdrawal reauth failed (code: \((error as NSError).code))")
                if (error as NSError).domain == AuthErrorDomain, code == .userMismatch {
                    showDeleteFailure("현재 로그인한 계정과 다른 \(provider.displayName) 계정입니다.\n가입한 \(provider.displayName) 계정으로 다시 시도해주세요.")
                } else {
                    showDeleteFailure("본인 확인에 실패했습니다. 다시 시도해주세요.")
                }
            }
        }
    }

    // 재인증 후 계정 삭제 (비밀번호 입력 후 호출)
    // 소셜이 함께 연결된 계정은 user.email이 소셜 이메일일 수 있어 비밀번호 로그인 이메일 사용
    func reauthenticateAndDelete(password: String) {
        guard let user = Auth.auth().currentUser,
              let email = user.providerData.first(where: { $0.providerID == "password" })?.email ?? user.email else {
            showDeleteFailure("사용자 정보가 없습니다. 다시 로그인해주세요.")
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
        guard let user = Auth.auth().currentUser else {
            isProcessing = false
            return
        }
        let uid = user.uid
        let hasGoogle = user.providerData.contains { $0.providerID == SocialAuthProvider.google.providerID }
        isProcessing = true
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
            if let error = encounteredError {
                print("[Auth] Withdrawal cleanup failed (code: \((error as NSError).code))")
                self.isProcessing = false
                self.showDeleteFailure("탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.")
                return
            }

            // users 문서 삭제 후 Auth 계정 삭제가 실패해도, 다음 실행 시 users 문서가 없는 계정으로 정리됨
            self.db.collection("users").document(uid).delete { [weak self] error in
                if let error = error {
                    print("[Auth] User document delete failed (code: \((error as NSError).code))")
                    self?.isProcessing = false
                    self?.showDeleteFailure("탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.")
                    return
                }

                user.delete { error in
                    if let error = error {
                        print("[Auth] Auth user delete failed (code: \((error as NSError).code))")
                        self?.isProcessing = false
                        self?.showDeleteFailure("탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.")
                        return
                    }
                    Task { @MainActor in
                        if hasGoogle {
                            await GoogleAuthService.disconnect()
                        }
                        self?.isProcessing = false
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

//
//  ProfileViewModel.swift
//  iOS_Project
//
//  Created by CHOI on 11/5/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class ProfileViewModel: ObservableObject {
    @Published var profile: ProfileModel?
    @Published var isEditing = false
    @Published var errorMessage: String? // 에러 메시지 상태 추가
    @Published var navigateToLogin = false // 로그인 화면으로 이동 플래그

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
            errorMessage = "생일은 8자리 숫자로 입력해야 합니다."
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
    
    // 계정 삭제
    func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }
        
        let uid = user.uid
        db.collection("users").document(uid).delete { [weak self] error in
            if let error = error {
                self?.errorMessage = "데이터 삭제 중 오류가 발생했습니다: \(error.localizedDescription)"
                return
            }
            
            user.delete { error in
                if let error = error {
                    self?.errorMessage = "계정 삭제 중 오류가 발생했습니다: \(error.localizedDescription)"
                } else {
                    // Firebase Auth에서 로그아웃 처리
                    do {
                        try Auth.auth().signOut()
                    } catch {
                        print("로그아웃 에러: \(error.localizedDescription)")
                    }
                    
                    // UserDefaults 업데이트
                    UserDefaults.standard.set(false, forKey: "isLoggedIn")
                    
                    //NotificationCenter를 통해 로그아웃 이벤트 전달(자동로그인 방지)
                    NotificationCenter.default.post(name: Notification.Name("UserDidLogout"), object: nil)
                    
                    // 일정 시간 후 로그인 화면으로 전환
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.navigateToLogin = true
                    }
                }
            }
        }
    }
}

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

class LoginViewModel: ObservableObject {
    @Published var user: SignUpUserModel = SignUpUserModel(username: "", password: "")
    @Published var isLoggedIn: Bool = false
    @Published var loginErrorMessage: String?
    
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
            // 로그인 성공 시
            print("로그인 성공")
            self?.isLoggedIn = true
            self?.loginErrorMessage = nil
            if let error = error {
                self?.loginErrorMessage = error.localizedDescription // 로그인 실패 시 오류 메시지 설정
                self?.isLoggedIn = false
                return
            }
            //로그인 성공 시, 자동 로그인
            self?.isLoggedIn = true
            self?.loginErrorMessage = nil
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
        }
    }
    
    //앱 시작 시 자동 로그인 상태 확인
    private func checkAutoLogin() {
        if Auth.auth().currentUser != nil || UserDefaults.standard.bool(forKey: "isLoggedIn") {
            self.isLoggedIn = true
        }else{
            self.isLoggedIn = false
        }
        
    }
    
    
}



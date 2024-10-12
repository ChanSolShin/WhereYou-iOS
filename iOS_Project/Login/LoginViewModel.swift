//
//  LoginViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Foundation
import Combine

class LoginViewModel: ObservableObject {
    @Published var user: SignUpModel = SignUpModel(username: "", password: "")
    @Published var isLoggedIn: Bool = false
    
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
    
    func login() {
        // 로그인 성공 로직 (예: API 호출 후 성공 시)
        isLoggedIn = true
    }

    func logout() {
        // 로그아웃 로직
        isLoggedIn = false
    }
    
}


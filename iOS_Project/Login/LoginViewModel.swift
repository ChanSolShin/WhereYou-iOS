//
//  LoginViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import Foundation
import Combine

class LoginViewModel: ObservableObject {
    @Published var user: SignUpModel = SignUpModel(username: "", password: "")
    
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
    
    // 이곳에 로그인 정보 확인 서버에서 사용자정보를 가져와서 일치하면 로그인 시키고 아니면 오류안내메시지
}

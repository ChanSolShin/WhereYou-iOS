//
//  CreateAccountViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

// CreateAccountViewModel.swift
import SwiftUI
import Combine

class CreateAccountViewModel: ObservableObject { // 이 항목들 서버로 보내서 저장.
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var realName: String = ""
    @Published var birthday: String = ""
    @Published var phoneNumber: String = ""
    
    // 회원가입 버튼이 정상적으로 눌려지기 위한 조건. 이 조건을 충족시키지 못할 경우 회원가입 버튼이 눌리지 않음.
    var successCreate: Bool {
        return username.isEmpty || !isValidEmail || password.isEmpty || confirmPassword.isEmpty || !passwordMatches || realName.isEmpty || birthday.count != 8 || phoneNumber.count != 11
    }
    
    var passwordMatches: Bool {
        return !confirmPassword.isEmpty && password == confirmPassword
    }
    
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: username)
    }
}

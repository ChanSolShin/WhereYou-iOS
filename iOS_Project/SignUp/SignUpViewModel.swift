//
//  CreateAccountViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

// CreateAccountViewModel.swift
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

class SignUpViewModel: ObservableObject { // 이 항목들 서버로 보내서 저장.
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var realName: String = ""
    @Published var birthday: String = ""
    @Published var phoneNumber: String = ""
    @Published var signUpErrorMessage: String?
    @Published var signUpSuccess: Bool = false
    
   
    
    private var db = Firestore.firestore()
    
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
    
    func signUp() {
            Auth.auth().createUser(withEmail: username, password: password) { [weak self] authResult, error in
                if let error = error {
                    if let errCode = AuthErrorCode(rawValue: error._code) {
                        switch errCode {
                        case .emailAlreadyInUse:
                            self?.signUpErrorMessage = "이미 가입된 이메일입니다."
                        default:
                            self?.signUpErrorMessage = error.localizedDescription
                        }
                    }
                    self?.signUpSuccess = false
                    return
                }
                
                guard let user = authResult?.user else {
                    self?.signUpErrorMessage = "사용자 정보를 가져올 수 없습니다."
                    return
                }
                
                // Firestore에 사용자 정보 저장
                self?.saveUserDataToFirestore(uid: user.uid)
            }
        }
    
    // Firestore에 사용자 정보를 저장하는 메서드
    private func saveUserDataToFirestore(uid: String) {
        let userData: [String: Any] = [
            "email": username,
            "name": realName,
            "phoneNumber": phoneNumber,
            "birthday": birthday
        ]
        
        db.collection("users").document(uid).setData(userData) { [weak self] error in
            if let error = error {
                print("Firestore 저장 오류: \(error.localizedDescription)")
                self?.signUpErrorMessage = "Firestore 저장 오류: \(error.localizedDescription)"
                self?.signUpSuccess = false
            } else {
                // Firestore 저장 성공
                print("Firestore 저장 성공")
                self?.signUpSuccess = true
            }
        }
    }
    
}

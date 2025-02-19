//
//  CreateAccountViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

class SignUpViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var realName: String = ""
    @Published var birthday: String = ""
    @Published var phoneNumber: String = ""
    @Published var signUpErrorMessage: String?
    @Published var signUpErrorMessageColor: Color = .red 
    @Published var signUpSuccess: Bool = false

    private var db = Firestore.firestore()

    var successCreate: Bool {
        return username.isEmpty || !isValidEmail || password.count < 6 || confirmPassword.isEmpty || !passwordMatches || realName.isEmpty || birthday.count != 8 || phoneNumber.count != 11
    }

    var passwordMatches: Bool {
        return !confirmPassword.isEmpty && password == confirmPassword
    }

    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: username)
    }

    func checkEmailAvailability(completion: @escaping (Bool) -> Void) {
        db.collection("users").whereField("email", isEqualTo: username).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error checking email availability: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let snapshot = querySnapshot, snapshot.isEmpty {
                completion(true)
            } else {
                completion(false)
            }
        }
    }

    func signUp() {
        signUpErrorMessage = nil

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

    private func saveUserDataToFirestore(uid: String) {
        let userData: [String: Any] = [
            "email": username,
            "name": realName,
            "phoneNumber": phoneNumber,
            "birthday": birthday,
            "loginStatus": false,                  // 로그인 여부
            "createdAt": Timestamp(date: Date())  // 회원가입 날짜
        ]

        db.collection("users").document(uid).setData(userData) { [weak self] error in
            if let error = error {
                print("Firestore 저장 오류: \(error.localizedDescription)")
                self?.signUpErrorMessage = "Firestore 저장 오류: \(error.localizedDescription)"
                self?.signUpSuccess = false
            } else {
                print("Firestore 저장 성공")
                self?.signUpSuccess = true
            }
        }
    }
}

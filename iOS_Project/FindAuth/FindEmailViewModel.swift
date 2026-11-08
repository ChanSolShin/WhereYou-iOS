//
//  FindEmailViewModel.swift
//  iOS_Project
//
//  Created by CHOI on 10/31/24.
//

import SwiftUI
import FirebaseFirestore

class FindEmailViewModel: ObservableObject {
    @Published var model = FindEmailModel(name: "", birthday: "", phoneNumber: "")
    // 조회된 계정의 로그인 수단 안내 (이메일은 마스킹)
    @Published var resultMessage: String?
    @Published var errorMessage: String?
    @Published var selectedCountryCode: String = ""

    // 생년월일은 선택 입력 (가입 시 생년월일을 입력하지 않은 계정도 조회 가능)
    // 가입 시 입력한 계정은 생년월일까지 일치해야 조회됨
    func findEmail(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let formattedPhone = formatPhoneNumber(model.phoneNumber)
        let birthday = model.birthday

        resultMessage = nil
        db.collection("users")
            .whereField("name", isEqualTo: model.name)
            .whereField("phoneNumber", isEqualTo: formattedPhone)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("[FindEmail] Lookup failed (code: \((error as NSError).code))")
                    self.errorMessage = "계정을 조회하지 못했습니다. 잠시 후 다시 시도해주세요."
                    completion(false)
                    return
                }
                let matched = snapshot?.documents.first { document in
                    (document.get("birthday") as? String ?? "") == birthday
                }
                guard let data = matched?.data() else {
                    self.errorMessage = "일치하는 계정이 없습니다.\n가입 시 생년월일을 입력했다면 함께 입력해주세요."
                    completion(false)
                    return
                }
                self.resultMessage = UserAuthInfo.loginGuideMessage(for: data)
                completion(true)
            }
    }

    // 전화번호 유효성 검사
    var isPhoneNumberValid: Bool {
        let phone = model.phoneNumber

        switch selectedCountryCode {
        case "+82":
            // "010" → 11자리, "10" → 10자리
            if phone.hasPrefix("010") {
                return phone.count == 11
            } else if phone.hasPrefix("10") {
                return phone.count == 10
            }
            return false
        case "+1":
            return phone.count == 10
        case "+44":
            return phone.count == 10 || phone.count == 11
        default:
            return !phone.isEmpty
        }
    }

    // 전화번호 포맷
    private func formatPhoneNumber(_ number: String) -> String {
        if selectedCountryCode == "+82" {
            var digits = number
            if digits.hasPrefix("0") {
                digits = String(digits.dropFirst())
            }
            return selectedCountryCode + digits
        } else {
            if number.hasPrefix("+") {
                return number
            }
            return selectedCountryCode + number
        }
    }
}

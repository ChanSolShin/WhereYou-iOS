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
    @Published var foundEmail: String?
    @Published var errorMessage: String?
    @Published var selectedCountryCode: String = ""

    func findEmail(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let formattedPhone = formatPhoneNumber(model.phoneNumber)

        db.collection("users")
            .whereField("name", isEqualTo: model.name)
            .whereField("birthday", isEqualTo: model.birthday)
            .whereField("phoneNumber", isEqualTo: formattedPhone)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                } else if let document = snapshot?.documents.first,
                          let email = document.get("email") as? String {
                    self.foundEmail = email
                    completion(true)
                } else {
                    self.errorMessage = "일치하는 계정이 없습니다."
                    self.foundEmail = nil
                    completion(false)
                }
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

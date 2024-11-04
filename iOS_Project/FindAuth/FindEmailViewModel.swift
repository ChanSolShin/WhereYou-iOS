//
//  FindEmailViewModel.swift
//  iOS_Project
//
//  Created by CHOI on 10/31/24.
//

import SwiftUI
import FirebaseFirestore

class FindEmailViewModel: ObservableObject {
    @Published var name = ""
    @Published var birthday = ""
    @Published var phoneNumber = ""
    @Published var foundEmail: String?
    @Published var errorMessage: String?
    
    func findEmail(completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        db.collection("users")
            .whereField("name", isEqualTo: name)
            .whereField("birthday", isEqualTo: birthday)
            .whereField("phoneNumber", isEqualTo: phoneNumber)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                } else if let document = snapshot?.documents.first, let email = document.get("email") as? String {
                    self.foundEmail = email
                    completion(true)
                } else {
                    self.errorMessage = "일치하는 계정이 없습니다."
                    self.foundEmail = nil
                    completion(false)
                }
            }
    }
}

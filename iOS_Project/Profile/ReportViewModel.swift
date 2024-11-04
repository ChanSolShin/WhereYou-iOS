//
//  ReportViewModel.swift
//  iOS_Project
//
//  Created by CHOI on 11/5/24.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class ReportViewModel: ObservableObject {
    @Published var reportContent = ""
    @Published var submissionStatus: String?
    
    private let db = Firestore.firestore()
    
    func submitReport() {
        guard let userEmail = Auth.auth().currentUser?.email else {
            submissionStatus = "로그인이 필요합니다."
            return
        }
        
        let reportData = [
            "content": reportContent,
            "email": userEmail,
            "timestamp": Timestamp(date: Date())
        ] as [String : Any]
        
        // Firestore에 문서를 추가하고 문서 ID는 자동 생성
        db.collection("report").addDocument(data: reportData) { error in
            if let error = error {
                print("Error submitting report: \(error)")
                self.submissionStatus = "신고 제출 실패: \(error.localizedDescription)"
            } else {
                self.submissionStatus = "신고가 성공적으로 제출되었습니다."
                self.reportContent = "" 
            }
        }
    }
}

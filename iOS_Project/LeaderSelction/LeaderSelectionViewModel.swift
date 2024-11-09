//
//  LeaderSelectionViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import Foundation
import FirebaseFirestore

class LeaderSelectionViewModel: ObservableObject {
    @Published var members: [User] = []  // 모임 멤버들
    @Published var isLoading: Bool = true  // 데이터 로딩 상태
    
    func fetchMeetingMembers(meetingID: String) {
        let db = Firestore.firestore()
        
        // 모임 데이터에서 meetingMembers(멤버 ID 목록) 가져오기
        db.collection("meetings").document(meetingID).getDocument { document, error in
            if let document = document, document.exists, let data = document.data() {
                // 모임의 멤버 ID 목록을 가져옴
                if let memberIDs = data["meetingMembers"] as? [String] {
                    self.fetchMemberDetails(memberIDs: memberIDs)
                }
            } else {
                print("Error fetching meeting data: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    
    
    private func fetchMemberDetails(memberIDs: [String]) {
        let db = Firestore.firestore()
        var fetchedMembers: [User] = []
        
        // 각 멤버의 정보를 가져옴
        let dispatchGroup = DispatchGroup()
        for memberID in memberIDs {
            dispatchGroup.enter()
            db.collection("users").document(memberID).getDocument { document, error in
                if let document = document, document.exists, let data = document.data() {
                    if let name = data["name"] as? String {
                        let user = User(id: memberID, name: name)
                        fetchedMembers.append(user)
                    }
                }
                dispatchGroup.leave()
            }
        }
        
        // 모든 멤버 정보를 가져온 후 업데이트
        dispatchGroup.notify(queue: .main) {
            self.members = fetchedMembers
            self.isLoading = false
        }
    }
}

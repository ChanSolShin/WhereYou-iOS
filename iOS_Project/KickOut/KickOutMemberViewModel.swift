//
//  KickOutMemberViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/14/24.
//

import Foundation
import FirebaseFirestore

class KickOutMemberViewModel: ObservableObject {
    @Published var members: [User] = []
    @Published var isLoading: Bool = true
    private let db = Firestore.firestore()
    
    func fetchMeetingMembers(meetingID: String) {
        isLoading = true
        
        db.collection("meetings").document(meetingID).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let document = document, document.exists, let data = document.data() {
                if let memberIDs = data["meetingMembers"] as? [String] {
                    self.fetchMemberDetails(memberIDs: memberIDs)
                } else {
                    print("No memberIDs found in meeting document")
                    self.isLoading = false
                }
            } else {
                print("Error fetching meeting data: \(error?.localizedDescription ?? "Unknown error")")
                self.isLoading = false
            }
        }
    }
    
    private func fetchMemberDetails(memberIDs: [String]) {
        var fetchedMembers: [User] = []
        
        let dispatchGroup = DispatchGroup()
        for memberID in memberIDs {
            dispatchGroup.enter()
            db.collection("users").document(memberID).getDocument { document, error in
                if let document = document, document.exists, let data = document.data() {
                    if let name = data["name"] as? String {
                        let user = User(id: memberID, name: name)
                        fetchedMembers.append(user)
                    }
                } else {
                    print("Error fetching user data for memberID \(memberID): \(error?.localizedDescription ?? "Unknown error")")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.members = fetchedMembers
            self.isLoading = false
            print("Fetched \(self.members.count) members for meetingID")
        }
    }
    
    // 선택된 멤버를 강퇴
    func kickOutMember(meetingID: String, memberID: String, completion: @escaping (Result<Void, Error>) -> Void) {
        db.collection("meetings").document(meetingID).updateData([
            "meetingMembers": FieldValue.arrayRemove([memberID])
        ]) { [weak self] error in
            if let error = error {
                print("Error removing member from meetingMembers array: \(error.localizedDescription)")
                completion(.failure(error))
            } else {
                self?.members.removeAll { $0.id == memberID }
                print("Member \(memberID) removed successfully.")
                completion(.success(()))
            }
        }
    }
}

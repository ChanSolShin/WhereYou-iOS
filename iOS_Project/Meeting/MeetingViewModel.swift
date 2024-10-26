//
//  MeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//

import Foundation
import CoreLocation
import FirebaseFirestore

class MeetingViewModel: ObservableObject {
    @Published var meetingLocation: CLLocationCoordinate2D?
    
    @Published var meetingMemberNames: [String: String] = [:] // [userID: userName]
    
    func selectMeeting(meeting: MeetingModel) {
        self.meetingLocation = meeting.meetingLocation
        
        
        for memberID in meeting.meetingMemberIDs {
            fetchUserName(byID: memberID) { [weak self] name in
                DispatchQueue.main.async {
                    self?.meetingMemberNames[memberID] = name // UI 업데이트
                }
            }
        }
    }
    
    private func fetchUserName(byID userID: String, completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        let usersCollection = db.collection("users")
        
        usersCollection.document(userID).getDocument { (document, error) in
            if let document = document, document.exists {
                if let userName = document.data()?["name"] as? String {
                    completion(userName)
                } else {
                    completion("Unknown")
                }
            } else {
                completion("Unknown")
            }
        }
    }
}

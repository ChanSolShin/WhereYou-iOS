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
    @Published var meetingMasterName: String = ""
    @Published var meetingMemberNames: [String: String] = [:] // [userID: userName]

    func selectMeeting(meeting: MeetingModel) {
        self.meetingLocation = meeting.meetingLocation
        fetchUserName(byID: meeting.meetingMasterID) { name in
            self.meetingMasterName = name
        }
        for memberID in meeting.meetingMemberIDs {
            fetchUserName(byID: memberID) { name in
                self.meetingMemberNames[memberID] = name
            }
        }
    }

    // Firebase에서 userID로 사용자 이름 가져오는 로직
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

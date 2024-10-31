//
//  MeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import Combine
import FirebaseAuth

class MeetingViewModel: ObservableObject {
    @Published var meetingLocation: CLLocationCoordinate2D?
    @Published var meetingMemberNames: [String: String] = [:]
    @Published var pendingMeetingRequests: [MeetingRequestModel] = []

    func selectMeeting(meeting: MeetingModel) {
        self.meetingLocation = meeting.meetingLocation

        for memberID in meeting.meetingMemberIDs {
            fetchUserName(byID: memberID) { [weak self] name in
                DispatchQueue.main.async {
                    self?.meetingMemberNames[memberID] = name
                }
            }
        }
    }

    private func fetchUserName(byID userID: String, completion: @escaping (String) -> Void) {
        let db = Firestore.firestore()
        db.collection("users").document(userID).getDocument { (document, error) in
            if let document = document, document.exists,
               let userName = document.data()?["name"] as? String {
                completion(userName)
            } else {
                completion("Unknown")
            }
        }
    }

    // 친구들에게 모임 초대 요청 보내기
    func sendMeetingRequest(toUserIDs: [String], meetingName: String, fromUserID: String, fromUserName: String) {
        let db = Firestore.firestore()
        
        for userID in toUserIDs {
            let request = MeetingRequestModel(id: UUID().uuidString, fromUserID: fromUserID, fromUserName: fromUserName, toUserID: userID, meetingName: meetingName, status: "pending")
            
            db.collection("meetingRequests").document(request.id).setData([
                "fromUserID": request.fromUserID,
                "fromUserName": request.fromUserName,
                "toUserID": request.toUserID,
                "meetingName": request.meetingName,
                "status": request.status
            ]) { error in
                if let error = error {
                    print("Error sending meeting request: \(error)")
                }
            }
        }
    }

    // 수락 및 거절 요청 처리
    func acceptMeetingRequest(requestID: String, fromUserID: String) {
        // 요청을 수락하고 필요한 로직 추가
        // 예: 해당 요청을 "accepted"로 업데이트하고, 모임 멤버로 추가
        let db = Firestore.firestore()
        db.collection("meetingRequests").document(requestID).updateData(["status": "accepted"]) { error in
            if let error = error {
                print("Error accepting meeting request: \(error)")
            } else {
                // 수락 후 추가 로직 구현
            }
        }
    }

    func rejectMeetingRequest(requestID: String) {
        // 요청을 거절하고 필요한 로직 추가
        let db = Firestore.firestore()
        db.collection("meetingRequests").document(requestID).updateData(["status": "rejected"]) { error in
            if let error = error {
                print("Error rejecting meeting request: \(error)")
            } else {
                // 거절 후 추가 로직 구현
            }
        }
    }

    func fetchPendingMeetingRequests() {
        let db = Firestore.firestore()
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }

        db.collection("meetingRequests")
            .whereField("toUserID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: "pending")
            .getDocuments { (querySnapshot, error) in
                if let error = error {
                    print("Error fetching pending meeting requests: \(error)")
                } else {
                    self.pendingMeetingRequests = querySnapshot?.documents.compactMap { document in
                        let data = document.data()
                        return MeetingRequestModel(
                            id: document.documentID,
                            fromUserID: data["fromUserID"] as? String ?? "",
                            fromUserName: data["fromUserName"] as? String ?? "",
                            toUserID: data["toUserID"] as? String ?? "",
                            meetingName: data["meetingName"] as? String ?? "",
                            status: data["status"] as? String ?? ""
                        )
                    } ?? []
                }
            }
    }
}

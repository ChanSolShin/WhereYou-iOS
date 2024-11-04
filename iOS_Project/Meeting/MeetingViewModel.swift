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
    @Published var showAlert: Bool = false
    @Published var errorMessage: String?

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
            db.collection("meetingRequests")
                .whereField("fromUserID", isEqualTo: fromUserID)
                .whereField("toUserID", isEqualTo: userID)
                .whereField("meetingName", isEqualTo: meetingName)
                .whereField("status", isEqualTo: "pending")
                .getDocuments { (snapshot, error) in
                    if let error = error {
                        print("Error checking existing requests: \(error)")
                        return
                    }
                }
        }
    }
    // 수락 및 거절 요청 처리
    func acceptMeetingRequest(requestID: String, fromUserID: String) {
        let db = Firestore.firestore()
        // 요청을 수락하고 필요한 로직 추가
        db.collection("meetingRequests").document(requestID).updateData(["status": "accepted"]) { error in
            if let error = error {
                print("Error accepting meeting request: \(error)")
            } else {
                // 수락 후 추가 로직 구현
                self.deleteMeetingRequest(requestID: requestID) // 요청 삭제
            }
        }
    }

    func rejectMeetingRequest(requestID: String) {
        let db = Firestore.firestore()
        // 요청을 거절하고 필요한 로직 추가
        db.collection("meetingRequests").document(requestID).updateData(["status": "rejected"]) { error in
            if let error = error {
                print("Error rejecting meeting request: \(error)")
            } else {
                self.deleteMeetingRequest(requestID: requestID)
            }
        }
    }

    // 요청 삭제
    private func deleteMeetingRequest(requestID: String) {
        let db = Firestore.firestore()
        db.collection("meetingRequests").document(requestID).delete { error in
            if let error = error {
                print("Error deleting meeting request: \(error)")
            } else {
                print("Successfully deleted meeting request with ID: \(requestID)")
                if let index = self.pendingMeetingRequests.firstIndex(where: { $0.id == requestID }) {
                    self.pendingMeetingRequests.remove(at: index)
                }
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

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
            if let error = error {
                print("Error fetching user name: \(error)")
                completion("Unknown")
            } else if let document = document, document.exists,
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
            let requestReference = db.collection("meetingRequests")
                .whereField("fromUserID", isEqualTo: fromUserID)
                .whereField("toUserID", isEqualTo: userID)
                .whereField("meetingName", isEqualTo: meetingName)
                .whereField("status", isEqualTo: "pending")
            
            requestReference.getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error checking existing requests: \(error)")
                    return
                }
                
                // 요청이 존재하지 않는 경우 새로운 요청을 추가합니다.
                if let documents = snapshot?.documents, documents.isEmpty {
                    self.createMeetingRequest(toUserID: userID, meetingName: meetingName, fromUserID: fromUserID, fromUserName: fromUserName)
                } else {
                    print("Request already exists for \(userID)")
                }
            }
        }
    }
    
    private func createMeetingRequest(toUserID: String, meetingName: String, fromUserID: String, fromUserName: String) {
        let db = Firestore.firestore()
        let newRequest: [String: Any] = [
            "fromUserID": fromUserID,
            "fromUserName": fromUserName,
            "toUserID": toUserID,
            "meetingName": meetingName,
            "status": "pending"
        ]
        
        db.collection("meetingRequests").addDocument(data: newRequest) { error in
            if let error = error {
                print("Error creating meeting request: \(error)")
            } else {
                print("Successfully created meeting request to \(toUserID)")
            }
        }
    }
    
    func acceptMeetingRequest(requestID: String, fromUserID: String) {
        let db = Firestore.firestore()
        db.collection("meetingRequests").document(requestID).updateData(["status": "accepted"]) { [weak self] error in
            if let error = error {
                print("Error accepting meeting request: \(error)")
            } else {
                self?.deleteMeetingRequest(requestID: requestID)
                // 요청 삭제 후 최신 요청 목록 불러오기
                self?.fetchPendingMeetingRequests()
            }
        }
    }
    
    func rejectMeetingRequest(requestID: String) {
        let db = Firestore.firestore()
        db.collection("meetingRequests").document(requestID).updateData(["status": "rejected"]) { [weak self] error in
            if let error = error {
                print("Error rejecting meeting request: \(error)")
            } else {
                self?.deleteMeetingRequest(requestID: requestID)
                // 요청 삭제 후 최신 요청 목록 불러오기
                self?.fetchPendingMeetingRequests()
            }
        }
    }
    
    private func updateMeetingRequestStatus(requestID: String, status: String) {
        let db = Firestore.firestore()
        db.collection("meetingRequests").document(requestID).updateData(["status": status]) { error in
            if let error = error {
                print("Error updating meeting request: \(error)")
            } else {
                self.deleteMeetingRequest(requestID: requestID) // 요청 삭제
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
    
    private var listener: ListenerRegistration?
    
    func fetchPendingMeetingRequests() {
        let db = Firestore.firestore()
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        // 기존 리스너 제거
        listener?.remove()
        
        // 새로운 리스너 추가
        listener = db.collection("meetingRequests")
            .whereField("toUserID", isEqualTo: currentUserID)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                if let error = error {
                    print("Error fetching pending meeting requests: \(error)")
                } else {
                    DispatchQueue.main.async {
                        self?.pendingMeetingRequests = querySnapshot?.documents.compactMap { document in
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
    }}

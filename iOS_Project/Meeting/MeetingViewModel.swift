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
    private func fetchMeetingDocumentID(for meetingName: String, completion: @escaping (String?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("meetings").whereField("meetingName", isEqualTo: meetingName).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching meeting document ID: \(error)")
                completion(nil)
            } else if let document = snapshot?.documents.first {
                // 첫 번째 문서의 ID 반환
                completion(document.documentID)
            } else {
                completion(nil)
            }
        }
    }
    
    // 친구들에게 모임 초대 요청 보내기
    func sendMeetingRequest(toUserIDs: [String], meetingName: String, fromUserID: String, fromUserName: String) {
        fetchMeetingDocumentID(for: meetingName) { [weak self] meetingID in
            guard let meetingID = meetingID else {
                print("Meeting document ID를 찾을 수 없습니다.")
                return
            }
            
            for userID in toUserIDs {
                let requestReference = Firestore.firestore().collection("meetingRequests")
                    .whereField("fromUserID", isEqualTo: fromUserID)
                    .whereField("toUserID", isEqualTo: userID)
                    .whereField("meetingName", isEqualTo: meetingName)
                    .whereField("status", isEqualTo: "pending")
                    .whereField("meetingID", isEqualTo: meetingID)
                
                requestReference.getDocuments { (snapshot, error) in
                    if let error = error {
                        print("Error checking existing requests: \(error)")
                        return
                    }
                    
                    // 요청이 없는 경우 새 요청 생성
                    if let documents = snapshot?.documents, documents.isEmpty {
                        self?.createMeetingRequest(toUserID: userID, meetingID: meetingID, meetingName: meetingName, fromUserID: fromUserID, fromUserName: fromUserName)
                    } else {
                        print("이미 \(userID)에게 보낸 요청이 있습니다.")
                    }
                }
            }
        }
    }
    private func createMeetingRequest(toUserID: String, meetingID: String, meetingName: String, fromUserID: String, fromUserName: String) {
        let db = Firestore.firestore()
        let newRequest: [String: Any] = [
            "fromUserID": fromUserID,
            "fromUserName": fromUserName,
            "toUserID": toUserID,
            "meetingName": meetingName,
            "meetingID": meetingID,
            "status": "pending"
        ]
        
        db.collection("meetingRequests").addDocument(data: newRequest) { error in
            if let error = error {
                print("Error creating meeting request: \(error)")
            } else {
                print("Successfully created meeting request to \(toUserID) with meetingID: \(meetingID)")
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
                                status: data["status"] as? String ?? "",
                                meetingID: data["meetingID"] as? String ?? ""  // meetingID 추가
                            )
                        } ?? []
                    }
                }
            }    }}

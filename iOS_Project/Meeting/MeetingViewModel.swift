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
    @Published var members: [User] = []
    @Published var meetingMasterID: String?
    
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
    
    func acceptMeetingRequest(requestID: String, toUserID: String) {
        let db = Firestore.firestore()
        
        // 요청 문서 가져오기
        db.collection("meetingRequests").document(requestID).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching meeting request: \(error)")
                return
            }
            
            if let document = document, document.exists {
                let meetingID = document.data()?["meetingID"] as? String ?? ""
                // 수락 요청 상태 업데이트
                self.updateMeetingRequestStatus(requestID: requestID, status: "accepted")
                
                // Meeting에 사용자 추가
                self.addUserToMeeting(meetingID: meetingID, userID: toUserID)
            }
        }
    }
    
    private func addUserToMeeting(meetingID: String, userID: String) {
        let db = Firestore.firestore()
        
        // meetings 컬렉션의 해당 문서 업데이트
        db.collection("meetings").document(meetingID).updateData([
            "meetingMembers": FieldValue.arrayUnion([userID])  // 사용자 ID 추가
        ]) { error in
            if let error = error {
                print("Error adding user to meeting: \(error)")
            } else {
                print("Successfully added user \(userID) to meeting with ID: \(meetingID)")
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
    func isMeetingMaster(meetingID: String, currentUserID: String, meetingMasterID: String) -> Bool {
            return meetingMasterID == currentUserID
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
    
    // 모임 나가기 기능
    func leaveMeeting(meetingID: String) {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return }
        
        let db = Firestore.firestore()
        
        db.collection("meetings").document(meetingID).getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching meeting: \(error)")
                return
            }
            
            if let document = document, document.exists {
                var meetingMasterID = document.data()?["meetingMaster"] as? String ?? ""
                let meetingMembers = document.data()?["meetingMembers"] as? [String] ?? []
                
                // 현재 사용자가 meetingMaster인 경우
                if meetingMasterID == currentUserID && meetingMembers.count > 1 {
                    // 모임장이므로, 랜덤으로 다른 멤버에게 모임장 권한 부여
                    if let newMeetingMaster = self?.getRandomOtherMember(currentUserID: currentUserID, members: meetingMembers) {
                        meetingMasterID = newMeetingMaster
                        db.collection("meetings").document(meetingID).updateData([
                            "meetingMaster": meetingMasterID
                        ]) { error in
                            if let error = error {
                                print("Error updating meeting master: \(error)")
                            } else {
                                print("Meeting master changed successfully to \(newMeetingMaster).")
                            }
                        }
                    }
                }
                
                // 만약 모임의 멤버가 1명이면 모임 자체를 삭제
                if meetingMembers.count == 1 {
                    db.collection("meetings").document(meetingID).delete { error in
                        if let error = error {
                            print("Error deleting meeting: \(error)")
                        } else {
                            print("Meeting deleted successfully.")
                        }
                    }
                    return
                }
                
                // 그 외의 경우는 모임에서 현재 사용자를 제거
                self?.removeUserFromMeeting(meetingID: meetingID, userID: currentUserID)
            }
        }
    }

    // 랜덤한 다른 멤버를 선택하는 함수
    func getRandomOtherMember(currentUserID: String, members: [String]) -> String? {
        // 현재 사용자가 모임 멤버 목록에 포함되어 있을 경우, 이를 제외한 나머지 멤버들 중에서 랜덤 선택
        let otherMembers = members.filter { $0 != currentUserID }
        
        // 만약 다른 멤버가 있다면, 랜덤으로 선택
        if let randomMember = otherMembers.randomElement() {
            return randomMember
        }
        
        return nil
    }
    
    // meetingMembers에서 사용자 ID 삭제
    private func removeUserFromMeeting(meetingID: String, userID: String) {
        let db = Firestore.firestore()
        
        db.collection("meetings").document(meetingID).updateData([
            "meetingMembers": FieldValue.arrayRemove([userID])
        ]) { error in
            if let error = error {
                print("Error removing user \(error)")
            } else {
                print("Successfully removed user \(userID) from meeting with ID: \(meetingID)")
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

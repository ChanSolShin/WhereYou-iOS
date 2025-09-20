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
import FirebaseDatabase

class MeetingViewModel: NSObject, ObservableObject {
    @Published var meetingMemberNames: [String: String] = [:]
    @Published var pendingMeetingRequests: [MeetingRequestModel] = []
    @Published var showAlert: Bool = false
    @Published var errorMessage: String?
    @Published var members: [User] = []
    @Published var meetingMasterID: String?
    @Published var selectedUserLocation: CLLocationCoordinate2D? // 유저 위치 표시
    @Published var trackedMemberID: String? // 현재 추적 중인 멤버 ID
    @Published var meetingDate: Date?
    
    private var meeting: MeetingModel? // 현재 선택된 모임
    private let realtimeDB = Database.database().reference()
    
    public let locationCoordinator: AppLocationCoordinator // 위치 코디네이터
    
    private var meetingListener: ListenerRegistration?
    private var memberListener: ListenerRegistration?

    private var db = Firestore.firestore()
    private var currentMemberIDs: [String] = []
    
    init(locationCoordinator: AppLocationCoordinator = AppLocationCoordinator.shared) {
        self.locationCoordinator = locationCoordinator
        super.init()
    }
    
    deinit {
        meetingListener?.remove()
        memberListener?.remove()
    }
    
    // 현재 로그인한 사용자 ID 가져오기
    func getCurrentUserID() -> String? {
        return Auth.auth().currentUser?.uid
    }

    // 모임 선택 및 초기화
    func selectMeeting(meeting: MeetingModel) {
        self.meeting = meeting
        DispatchQueue.main.async {
            self.trackedMemberID = nil
        }
        
        for memberID in meeting.meetingMemberIDs {
            fetchUserName(byID: memberID) { [weak self] name in
                DispatchQueue.main.async {
                    self?.meetingMemberNames[memberID] = name
                }
            }
        }
        
        // AppLocationCoordinator에 모임 등록
        locationCoordinator.registerMeeting(meeting)
    }
    
    private func listenToMeetingChanges(meetingID: String) {
           meetingListener?.remove()
           
           let db = Firestore.firestore()
           meetingListener = db.collection("meetings").document(meetingID).addSnapshotListener { [weak self] (document, error) in
               guard let self = self else { return }
               if let document = document, document.exists {
                   if let timestamp = document.data()?["meetingDate"] as? Timestamp {
                       DispatchQueue.main.async {
                           self.meetingDate = timestamp.dateValue()
                       }
                   }
               }
           }
       }
    
    private func listenToMemberNameChanges(memberIDs: [String]) {
        memberListener?.remove()
        let ids = memberIDs
        guard !ids.isEmpty else { return }
        let db = Firestore.firestore()
        memberListener = db.collection("users").whereField(FieldPath.documentID(), in: ids)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                guard let documents = querySnapshot?.documents else { return }
                DispatchQueue.main.async {
                    for document in documents {
                        if let name = document.data()["name"] as? String {
                            self.meetingMemberNames[document.documentID] = name
                        }
                    }
                }
            }
    }

    
    
    // 특정 유저 위치 가져오기 및 추적 시작
    func moveToUserLocation(userID: String) {
        guard let meetingID = meeting?.id else { return }

        let firestoreDB = Firestore.firestore()
        // Firestore에서 모임 날짜 가져오기
        firestoreDB.collection("meetings").document(meetingID).getDocument { [weak self] (document, error) in
            guard let self = self else { return }

            if let error = error {
                print("Firestore에서 데이터 가져오기 실패: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "모임 정보를 불러올 수 없습니다."
                }
                return
            }

            guard let document = document, document.exists,
                  let meetingTimestamp = document.data()?["meetingDate"] as? Timestamp else {
                print("모임 날짜를 가져올 수 없습니다.")
                DispatchQueue.main.async {
                    self.errorMessage = "모임 날짜 정보를 불러올 수 없습니다."
                }
                return
            }

            // Firebase에서 가져온 Timestamp를 Date로 변환
            let meetingDate = meetingTimestamp.dateValue()
            let timeBeforeMeeting = meetingDate.addingTimeInterval(-3 * 3600) // 3시간 전
            let timeAfterMeeting = meetingDate.addingTimeInterval(1 * 3600)   // 1시간 후

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm"
            let formattedStartTime = dateFormatter.string(from: timeBeforeMeeting)
            let formattedEndTime = dateFormatter.string(from: timeAfterMeeting)

            // 현재 시간과 모임 시간 비교
            let currentTime = Date()
            guard currentTime >= timeBeforeMeeting && currentTime <= timeAfterMeeting else {
                let errorMessage = "모임 당일 \(formattedStartTime)~\(formattedEndTime) 에 위치 조회가 가능합니다."
                print(errorMessage)
                DispatchQueue.main.async {
                    self.errorMessage = errorMessage
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.errorMessage = nil
                }
                return
            }

            // 동일한 멤버 버튼이 눌린 경우 추적 중지
            if self.trackedMemberID == userID {
                print("Stopped tracking user \(userID)")
                self.stopTrackingMember()
                return
            }

            // 기존에 추적 중인 멤버가 있다면 중지
            self.stopTrackingMember()

            // 새로운 멤버 추적 시작
            print("Started tracking user \(userID)")
            DispatchQueue.main.async {
                self.trackedMemberID = userID
            }
            self.fetchMemberLocation(userID: userID)
        }
    }

    // 특정 멤버의 위치를 Firebase에서 가져와 업데이트
    func fetchMemberLocation(userID: String) {
        guard let meetingID = meeting?.id else {
            print("Meeting ID is nil")
            return
        }

        print("Fetching location for userID \(userID) in meeting \(meetingID)")

        // 실시간 위치 변경 감지
        realtimeDB.child("meetings").child(meetingID).child("locations").child(userID)
            .observe(.value) { [weak self] snapshot in
                if let locationData = snapshot.value as? [String: Any],
                   let latitude = locationData["latitude"] as? CLLocationDegrees,
                   let longitude = locationData["longitude"] as? CLLocationDegrees {
                    DispatchQueue.main.async {
                        self?.selectedUserLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                        print("Updated location for user \(userID): \(latitude), \(longitude)")
                    }
                } else {
                    print("Failed to fetch location for user \(userID). Snapshot: \(snapshot.value ?? "nil")")
                    DispatchQueue.main.async {
                        if self?.errorMessage != "멤버의 위치 정보를 불러올 수 없습니다." {
                            self?.errorMessage = "멤버의 위치 정보를 불러올 수 없습니다."
                        }
                    }
                }
            }
    }
    
    func stopTrackingMember() {
        guard let meetingID = meeting?.id, let userID = trackedMemberID else { return }
        realtimeDB.child("meetings").child(meetingID).child("locations").child(userID).removeAllObservers()
        DispatchQueue.main.async {
            self.trackedMemberID = nil
            self.selectedUserLocation = nil
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
    
    func fetchMeetingData(meetingID: String) {
        db.collection("meetings").document(meetingID)
            .addSnapshotListener { [weak self] document, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "데이터 로딩 중 오류 발생: \(error.localizedDescription)"
                    }
                    return
                }
                guard let document = document, document.exists else {
                    return
                }
                // 1) 날짜/이름 맵 UI 업데이트
                DispatchQueue.main.async {
                    if let date = document.data()? ["meetingDate"] as? Timestamp {
                        self?.meetingDate = date.dateValue()
                    }
                    if let memberNames = document.data()? ["meetingMemberNames"] as? [String: String] {
                        self?.meetingMemberNames = memberNames
                    }
                }
                // 2) 멤버 목록이 바뀌면, 이름 리스너를 새 멤버 배열로 재구독
                if let memberIDs = document.data()? ["meetingMembers"] as? [String] {
                    if memberIDs != self?.currentMemberIDs {
                        self?.currentMemberIDs = memberIDs
                        // 이름 플레이스홀더(선택): 아직 로드 안 된 멤버는 '불러오는 중...' 표시 유지
                        DispatchQueue.main.async {
                            for id in memberIDs where self?.meetingMemberNames[id] == nil {
                                self?.meetingMemberNames[id] = "불러오는 중..."
                            }
                        }
                        self?.listenToMemberNameChanges(memberIDs: memberIDs)
                    }
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
                DispatchQueue.main.async {
                    if let index = self.pendingMeetingRequests.firstIndex(where: { $0.id == requestID }) {
                        self.pendingMeetingRequests.remove(at: index)
                    }
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
                
                // 만약 모임의 멤버가 1명이면 모임 자체를 삭제 (요청 먼저 삭제)
                if meetingMembers.count == 1 {
                    // 관련된 meetingRequests 먼저 삭제
                    db.collection("meetingRequests").whereField("meetingID", isEqualTo: meetingID).getDocuments { snapshot, error in
                        if let error = error {
                            print("Error fetching meetingRequests: \(error)")
                            return
                        }

                        let batch = db.batch()
                        snapshot?.documents.forEach { doc in
                            batch.deleteDocument(doc.reference)
                        }

                        batch.commit { batchError in
                            if let batchError = batchError {
                                print("Error deleting meetingRequests: \(batchError)")
                                return
                            }

                            print("✅ 관련된 MeetingRequests 삭제 완료")

                            // meetingRequests 삭제 후 모임 삭제
                            db.collection("meetings").document(meetingID).delete { error in
                                if let error = error {
                                    print("Error deleting meeting: \(error)")
                                } else {
                                    print("✅ Meeting deleted successfully.")
                                }
                            }
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
            }
    }

    // 외부에서 호출 가능한: 특정 모임과 관련된 meetingRequests만 삭제하는 함수
    func deleteRequestsForMeeting(meetingID: String, completion: (() -> Void)? = nil) {
        let db = Firestore.firestore()
        db.collection("meetingRequests").whereField("meetingID", isEqualTo: meetingID)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ MeetingRequests 조회 실패: \(error)")
                    completion?()
                    return
                }

                let batch = db.batch()
                snapshot?.documents.forEach { doc in
                    batch.deleteDocument(doc.reference)
                }

                batch.commit { batchError in
                    if let batchError = batchError {
                        print("❌ MeetingRequests 삭제 실패: \(batchError)")
                    } else {
                        print("✅ 관련된 MeetingRequests 삭제 완료")
                    }
                    completion?()
                }
            }
    }
}

extension MeetingViewModel {
    // 위치 매니저 델리게이트 메소드 제거
}

//
//  AddMeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/17/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

class AddMeetingViewModel: ObservableObject {
    @Published var meeting: AddMeetingModel = AddMeetingModel()
    
    var successAddMeeting: Bool {
        return meeting.meetingName.isEmpty || meeting.meetingAddress == nil
    }
    
    func updateMeetingLocation(coordinate: CLLocationCoordinate2D, address: String) {
        meeting.meetingLocation = coordinate
        meeting.meetingAddress = address
    }
    
    func addCurrentUserToMeeting() {
        // 현재 사용자의 UID를 가져와서 meetingMaster에 추가
        if let currentUserUID = Auth.auth().currentUser?.uid {
            meeting.meetingMaster.append(currentUserUID)
        } else {
            print("현재 로그인한 사용자의 UID를 가져올 수 없습니다.")
        }
    }
    
    func addMeeting() {
        let db = Firestore.firestore()
        
        // 현재 사용자의 UID를 추가하여 meetingMembers 배열 생성
        let currentUserUID = Auth.auth().currentUser?.uid ?? ""
        meeting.meetingMaster.append(currentUserUID) // 현재 사용자 UID 마스터로 추가
        meeting.meetingMembers.append(currentUserUID)
        
        let meetingData: [String: Any] = [
            "meetingName": meeting.meetingName,
            "meetingDate": Timestamp(date: meeting.meetingDate), // Firestore에 저장할 때 Timestamp로 변환
            "meetingAddress": meeting.meetingAddress ?? "",
            "meetingLocation": GeoPoint(latitude: meeting.meetingLocation.latitude, longitude: meeting.meetingLocation.longitude),
            "meetingMembers": meeting.meetingMembers,
            "meetingMaster" : meeting.meetingMaster,
            "isLocationTrackingEnabled": false
        ]
        
        // Firestore에 모임 데이터 추가
        db.collection("meetings").addDocument(data: meetingData) { [weak self] error in
            if let error = error {
                print("모임을 추가하는 중 에러 발생: \(error)")
            } else {
                print("모임이 성공적으로 추가되었습니다.")
                self?.observeMeetingUpdates() // 모임이 추가된 후 리스너 시작
                self?.meeting = AddMeetingModel() // 초기화
            }
        }
    }
    
    // Firestore에서 모임 데이터 실시간으로 업데이트 확인
    func observeMeetingUpdates() {
        let db = Firestore.firestore()

        // Firestore에서 모든 모임을 조회 (모임 시간 체크)
        db.collection("meetings").whereField("isLocationTrackingEnabled", isEqualTo: false)
            .addSnapshotListener { [weak self] querySnapshot, error in
                if let error = error {
                    print("모임 데이터를 조회하는 중 에러 발생: \(error)")
                } else {
                    for document in querySnapshot?.documents ?? [] {
                        let data = document.data()
                        if let meetingDate = (data["meetingDate"] as? Timestamp)?.dateValue() {
                            self?.checkAndUpdateLocationTracking(meetingDate: meetingDate, documentReference: document.reference)
                        }
                    }
                }
            }
    }
    
    // 모임 시간이 3시간 이내인지 체크하고, 조건에 맞으면 업데이트
    func checkAndUpdateLocationTracking(meetingDate: Date, documentReference: DocumentReference) {
        let currentDate = Date()
        let timeDifference = meetingDate.timeIntervalSince(currentDate)
        
        // 3시간(10800초) 이내라면 isLocationTrackingEnabled를 true로 설정
        if timeDifference <= 10800 && timeDifference > 0 { // 3시간 이내지만 현재 시간보다 뒤여야 함
            // isLocationTrackingEnabled가 false일 때만 업데이트
            documentReference.updateData([
                "isLocationTrackingEnabled": true
            ]) { error in
                if let error = error {
                    print("isLocationTrackingEnabled 업데이트 오류: \(error)")
                } else {
                    print("isLocationTrackingEnabled 값이 성공적으로 true로 업데이트되었습니다.")
                }
            }
        }
    }
}

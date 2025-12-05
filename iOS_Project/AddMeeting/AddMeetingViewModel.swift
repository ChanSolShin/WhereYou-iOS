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
    
    init() {
        observeMeetingUpdates()
    }
    
    var successAddMeeting: Bool {
        return meeting.meetingName.isEmpty || meeting.meetingAddress == nil
    }
    
    func updateMeetingLocation(coordinate: CLLocationCoordinate2D, address: String) {
        meeting.meetingLocation = coordinate
        meeting.meetingAddress = address
    }
    
    func addCurrentUserToMeeting() {
        if let currentUserUID = Auth.auth().currentUser?.uid {
            meeting.meetingMaster.append(currentUserUID)
        } else {
            print("현재 로그인한 사용자의 UID를 가져올 수 없습니다.")
        }
    }
    
    func addMeeting() {
        let db = Firestore.firestore()
        
        let currentUserUID = Auth.auth().currentUser?.uid ?? ""
        meeting.meetingMaster.append(currentUserUID)
        meeting.meetingMembers.append(currentUserUID)
        
        let meetingData: [String: Any] = [
            "meetingName": meeting.meetingName,
            "meetingDate": Timestamp(date: meeting.meetingDate),
            "meetingAddress": meeting.meetingAddress ?? "",
            "meetingLocation": GeoPoint(latitude: meeting.meetingLocation.latitude, longitude: meeting.meetingLocation.longitude),
            "meetingMembers": meeting.meetingMembers,
            "meetingMaster": meeting.meetingMaster,
            "isLocationTrackingEnabled": false
        ]
        
        db.collection("meetings").addDocument(data: meetingData) { [weak self] error in
            if let error = error {
                print("모임을 추가하는 중 에러 발생: \(error)")
            } else {
                print("모임이 성공적으로 추가되었습니다.")
                self?.observeMeetingUpdates()
                self?.meeting = AddMeetingModel()
            }
        }
    }
    
    func observeMeetingUpdates() {
        let db = Firestore.firestore()
        print("Firestore 리스너 시작")
        
        db.collection("meetings").addSnapshotListener { [weak self] querySnapshot, error in
            if let error = error {
                print("Firestore 리스너 오류: \(error)")
                return
            }
            
            print("🔥 Firestore 데이터 변경 감지됨: \(querySnapshot?.documents.count ?? 0)개 문서")
            
            for document in querySnapshot?.documents ?? [] {
                let data = document.data()
                if let meetingDate = (data["meetingDate"] as? Timestamp)?.dateValue(),
                   let isTrackingEnabled = data["isLocationTrackingEnabled"] as? Bool {
                    
                    print("감지된 모임 시간: \(meetingDate), 위치 추적 상태: \(isTrackingEnabled)")
                    
                    self?.checkAndUpdateLocationTracking(
                        meetingDate: meetingDate,
                        isTrackingEnabled: isTrackingEnabled,
                        documentReference: document.reference
                    )
                } else {
                    print(" meetingDate 또는 isLocationTrackingEnabled 값이 올바르지 않음")
                }
            }
        }
    }
    
    func checkAndUpdateLocationTracking(meetingDate: Date, isTrackingEnabled: Bool, documentReference: DocumentReference) {
        let currentDate = Date()
        let timeDifference = meetingDate.timeIntervalSince(currentDate)
        
        if timeDifference <= 10800 && timeDifference > 0 {
            if !isTrackingEnabled {
                documentReference.updateData(["isLocationTrackingEnabled": true]) { error in
                    if let error = error {
                        print("isLocationTrackingEnabled 업데이트 오류: \(error)")
                    } else {
                        print("isLocationTrackingEnabled 값이 true로 업데이트됨")
                    }
                }
            }
        } else {
            if isTrackingEnabled {
                documentReference.updateData(["isLocationTrackingEnabled": false]) { error in
                    if let error = error {
                        print("isLocationTrackingEnabled 업데이트 오류: \(error)")
                    } else {
                        print("isLocationTrackingEnabled 값이 false로 업데이트됨")
                    }
                }
            }
        }
    }
    
    
}

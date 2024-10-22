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

    struct Meeting {
        var meetingName: String = ""
        var meetingDate: Date = Date()
        var meetingAddress: String? = nil
        var meetingLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        var meetingMembers: [String] = [] 
    }
    
    func updateMeetingLocation(coordinate: CLLocationCoordinate2D, address: String) {
        meeting.meetingLocation = coordinate
        meeting.meetingAddress = address
    }

    func addCurrentUserToMeeting() {
        // 현재 사용자의 UID를 가져와서 meetingMembers에 추가
        if let currentUserUID = Auth.auth().currentUser?.uid {
            meeting.meetingMembers.append(currentUserUID)
        } else {
            print("현재 로그인한 사용자의 UID를 가져올 수 없습니다.")
        }
    }
    
    func addMeeting() {
        let db = Firestore.firestore()

        // 현재 사용자의 UID를 추가하여 meetingMembers 배열 생성
        let currentUserUID = Auth.auth().currentUser?.uid ?? ""
        meeting.meetingMembers.append(currentUserUID) // 현재 사용자 UID 추가

        let meetingData: [String: Any] = [
            "meetingName": meeting.meetingName,
            "meetingDate": Timestamp(date: meeting.meetingDate), // Firestore에 저장할 때 Timestamp로 변환
            "meetingAddress": meeting.meetingAddress ?? "",
            "meetingLocation": GeoPoint(latitude: meeting.meetingLocation.latitude, longitude: meeting.meetingLocation.longitude),
            "meetingMembers": meeting.meetingMembers // 업데이트된 meetingMembers 배열
        ]

        db.collection("meetings").addDocument(data: meetingData) { error in
            if let error = error {
                print("모임을 추가하는 중 에러 발생: \(error)")
            } else {
                print("모임이 성공적으로 추가되었습니다.")
                self.meeting = AddMeetingModel() // 초기화
            }
        }
    }
}

//
//  AddMeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/17/24.
//

import SwiftUI
import CoreLocation
import NMapsMap

class AddMeetingViewModel: ObservableObject {
    @Published var meeting: AddMeetingModel = AddMeetingModel( // 이 정보들을 Firebase로 보내야함
         
        )

    struct Meeting {
        var meetingName: String = ""
        var meetingDate: Date = Date()
        var meetingAddress: String? = nil
        var meetingLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    func updateMeetingLocation(coordinate: CLLocationCoordinate2D, address: String) {
            // meeting의 속성을 직접 업데이트
            meeting.meetingLocation = coordinate
            meeting.meetingAddress = address
        }
    
    
    func addMeeting() {
        // 파이어베이스로 속성 보내는 로직. 속성을 보내면 AddMeetingModel 초기화
    }
}



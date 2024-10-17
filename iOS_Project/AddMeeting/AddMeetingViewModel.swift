//
//  AddMeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/17/24.
//

import SwiftUI
import Foundation
import CoreLocation

class AddMeetingViewModel: ObservableObject {
    @Published var meeting: AddMeetingModel = AddMeetingModel(
            meetingName: "",
            meetingDate: Date(), // 현재 날짜로 초기화
            meetingLocation: CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0), // 기본 좌표값
            meetingMemberID: [] // 빈 배열로 초기화
        )
    func addMeeting() {
        
    }
}

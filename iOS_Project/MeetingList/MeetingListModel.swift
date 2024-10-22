//
//  MeetinfListModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import Foundation
import CoreLocation

struct MeetingListModel: Identifiable {
    var id: UUID // UUID로 정의
    var title: String
    var date: Date
    var meetingAddress: String // 모임 주소
    var meetingLocation: CLLocationCoordinate2D // 모임 좌표

    // 초기화 메서드
    init(title: String, date: Date, meetingAddress: String, meetingLocation: CLLocationCoordinate2D) {
        self.id = UUID() // 새로운 UUID 생성
        self.title = title
        self.date = date
        self.meetingAddress = meetingAddress
        self.meetingLocation = meetingLocation
    }
}

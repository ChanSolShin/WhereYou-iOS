//
//  MeetingModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//

import Foundation
import CoreLocation

struct MeetingModel {
    var id: UUID
    var title: String
    var date: Date
    var meetingAddress: String
    var meetingLocation: CLLocationCoordinate2D
 

    init(title: String, date: Date, meetingAddress: String, meetingLocation: CLLocationCoordinate2D) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.meetingAddress = meetingAddress
        self.meetingLocation = meetingLocation
  
    }
}

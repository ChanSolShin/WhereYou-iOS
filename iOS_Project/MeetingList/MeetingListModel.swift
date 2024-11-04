//
//  MeetinfListModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import Foundation
import CoreLocation

struct MeetingListModel: Identifiable {
    var id: String 
    var title: String
    var date: Date
    var meetingAddress: String
    var meetingLocation: CLLocationCoordinate2D
    var meetingMemberIDs: [String]
    var meetingMasterID: String

    init(id: String, title: String, date: Date, meetingAddress: String, meetingLocation: CLLocationCoordinate2D, meetingMemberIDs: [String], meetingMasterID: String) {
        self.id = id
        self.title = title
        self.date = date
        self.meetingAddress = meetingAddress
        self.meetingLocation = meetingLocation
        self.meetingMemberIDs = meetingMemberIDs
        self.meetingMasterID = meetingMasterID
    }
}

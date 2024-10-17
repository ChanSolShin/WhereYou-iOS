//
//  AddMeetingModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/17/24.
//

import Foundation
import CoreLocation
import SwiftUI

struct AddMeetingModel {
    var meetingName: String
    var meetingDate: Date
    var meetingLocation: CLLocationCoordinate2D
    var meetingMemberID: [String] // 사용자 UID
}

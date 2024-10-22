//
//  AddMeetingModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/17/24.
//

import Foundation
import CoreLocation
import SwiftUI
import NMapsMap

struct AddMeetingModel {
    var meetingName: String = " "
    var meetingDate: Date = Date()
    var meetingLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 0.0, longitude: 0.0) // 좌표
    var meetingAddress: String? = nil // 주소
    var meetingMembers: [String] = []
}

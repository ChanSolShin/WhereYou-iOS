//
//  MeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//

import Foundation
import CoreLocation
import FirebaseFirestore

class MeetingViewModel: ObservableObject {
    @Published var meetingLocation: CLLocationCoordinate2D?

    func selectMeeting(meeting: MeetingModel) {
        self.meetingLocation = meeting.meetingLocation
    }
}

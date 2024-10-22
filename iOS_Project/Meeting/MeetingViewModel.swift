//
//  MeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//

import Foundation
import CoreLocation

class MeetingViewModel: ObservableObject {
    @Published var selectedMeeting: MeetingModel?

    func selectMeeting(meeting: MeetingModel) {
        self.selectedMeeting = meeting
    }
}

//
//  MeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import NMapsMap

struct MeetingView: View {
    var meeting: MeetingListModel

    var title: String = "모임장소: "
    var body: some View {
            VStack {
                Text(title + meeting.meetingAddress)
                    .font(.headline)
                MeetingMapView(meeting: MeetingModel(title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation))
                    .frame( height: 300)
            }
            .navigationTitle(meeting.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

//
//  MeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import NMapsMap
import FirebaseAuth
import FirebaseFirestore

struct MeetingView: View {
    var meeting: MeetingListModel
    @ObservedObject var meetingViewModel: MeetingViewModel

    var title: String = "모임장소: "
    
    var body: some View {
        VStack {
            Text(title + meeting.meetingAddress)
                .font(.headline)
            
            MeetingMapView(meeting: MeetingModel(title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation, meetingMemberIDs: meeting.meetingMemberIDs, meetingMasterID: meeting.meetingMasterID))
                .frame(height: 300)


            ForEach(meeting.meetingMemberIDs, id: \.self) { memberID in
                Button(action: {
                }) {
                    Text(meetingViewModel.meetingMemberNames[memberID] ?? memberID) // 이름으로 표시
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.vertical, 2)
            }
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

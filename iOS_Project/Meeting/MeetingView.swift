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
    @ObservedObject var meetingViewModel: MeetingViewModel

    var title: String = "모임장소: "
    
    var body: some View {
        VStack {
            Text(title + meeting.meetingAddress)
                .font(.headline)
            MeetingMapView(meeting: MeetingModel(title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation, meetingMemberIDs: meeting.meetingMemberIDs, meetingMasterID: meeting.meetingMasterID))
                .frame(height: 300)
            
            // 모임장의 이름 표시
            Button(action: {
                // 모임장 이름 버튼 클릭 시 할 동작
                print("\(meetingViewModel.meetingMasterName) 버튼 클릭됨")
            }) {
                Text(meetingViewModel.meetingMasterName)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.vertical, 4)
            
            // 멤버들의 이름 표시
            ForEach(meeting.meetingMemberIDs, id: \.self) { memberID in
                Button(action: {
                    // 멤버 이름 버튼 클릭 시 할 동작
                    print("\(meetingViewModel.meetingMemberNames[memberID] ?? "Unknown") 버튼 클릭됨")
                }) {
                    Text(meetingViewModel.meetingMemberNames[memberID] ?? "Unknown") // 이름을 표시
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
        .onAppear {
            meetingViewModel.selectMeeting(meeting: MeetingModel(title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation, meetingMemberIDs: meeting.meetingMemberIDs, meetingMasterID: meeting.meetingMasterID))
        }
    }
}

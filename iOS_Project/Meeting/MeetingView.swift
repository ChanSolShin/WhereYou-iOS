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
                MeetingMapView(meeting: MeetingModel(title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation, meetingMemberIDs: meeting.meetingMemberIDs))
                    .frame( height: 300)
                ForEach(meeting.meetingMemberIDs, id: \.self) { memberID in
                               Button(action: {
                                   // 버튼 클릭 시 할 동작
                                   print("\(memberID) 버튼 클릭됨")
                               }) {
                                   Text(memberID) // ID 대신 이름을 사용하고 싶다면, ID를 이름으로 매핑하는 로직 추가 필요
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

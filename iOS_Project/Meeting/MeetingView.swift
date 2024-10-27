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
    @State private var title: String = "모임장소" //
    
    var body: some View {
        VStack {
            
            Text(title)
                .font(.title2)
            
            MeetingMapView(
                meeting: MeetingModel(
                    title: meeting.title,
                    date: meeting.date,
                    meetingAddress: meeting.meetingAddress,
                    meetingLocation: meeting.meetingLocation,
                    meetingMemberIDs: meeting.meetingMemberIDs,
                    meetingMasterID: meeting.meetingMasterID
                )
            )
            .frame(height: 300)
            
            Button(action: {
                title = "모임장소"
                // 이곳에 모임장소의 위치를 Map에 업데이트하는 코드
            }) {
                Text("모임장소")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            // 멤버 버튼을 가로 3개씩 배치
            ForEach(0..<meeting.meetingMemberIDs.count/3 + (meeting.meetingMemberIDs.count % 3 > 0 ? 1 : 0), id: \.self) { rowIndex in
                HStack {
                    // 각 행에서 3개의 버튼 생성
                    ForEach(0..<3) { columnIndex in
                        let index = rowIndex * 3 + columnIndex
                        if index < meeting.meetingMemberIDs.count {
                            let memberID = meeting.meetingMemberIDs[index]
                            Button(action: {
                                title = (meetingViewModel.meetingMemberNames[memberID] ?? "멤버") + "의 위치"
                                // 이곳에 버튼에 해당하는 사람의 현재위치정보를 Map에 업데이트하는 코드
                                
                            }) {
                                Text(meetingViewModel.meetingMemberNames[memberID] ?? "멤버 불러오는 중 ...")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            
        }
        .onAppear {
            meetingViewModel.selectMeeting(meeting: MeetingModel(
                title: meeting.title,
                date: meeting.date,
                meetingAddress: meeting.meetingAddress,
                meetingLocation: meeting.meetingLocation,
                meetingMemberIDs: meeting.meetingMemberIDs,
                meetingMasterID: meeting.meetingMasterID
            ))
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

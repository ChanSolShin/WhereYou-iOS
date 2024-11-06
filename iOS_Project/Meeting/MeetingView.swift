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
    @State private var title: String = "모임장소"
    @State private var showingAddFriendModal = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showActionSheet = false
    
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
            }) {
                Text("모임장소")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            ForEach(0..<meeting.meetingMemberIDs.count/3 + (meeting.meetingMemberIDs.count % 3 > 0 ? 1 : 0), id: \.self) { rowIndex in
                HStack {
                    ForEach(0..<3) { columnIndex in
                        let index = rowIndex * 3 + columnIndex
                        if index < meeting.meetingMemberIDs.count {
                            let memberID = meeting.meetingMemberIDs[index]
                            Button(action: {
                                title = (meetingViewModel.meetingMemberNames[memberID] ?? "멤버") + "의 위치"
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // 친구 추가 버튼
                    Button(action: {
                        showingAddFriendModal = true
                    }) {
                        Image(systemName: "person.badge.plus")
                    }

                    // 모임 관리 버튼 (가장 오른쪽)
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .imageScale(.large)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFriendModal) {
            AddSelectedFriend(meeting: meeting)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
        }
        .onReceive(meetingViewModel.$errorMessage) { message in
            if let message = message {
                alertMessage = message
                showAlert = true
            }
        }
        .actionSheet(isPresented: $showActionSheet) {
            ActionSheet(
                title: Text("모임 관리"),
                message: Text("원하는 작업을 선택하세요."),
                buttons: [
                    .default(Text("모임수정")) {
                        // 모임 수정 액션 추가
                        print("모임 수정 선택됨")
                    },
                    .destructive(Text("나가기")) {
                        // 모임 나가기 액션 추가
                        print("모임 나가기 선택됨")
                    },
                    .cancel(Text("취소"))
                ]
            )
        }
    }
}

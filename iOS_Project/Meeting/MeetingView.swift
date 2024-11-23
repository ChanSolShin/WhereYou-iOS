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
    @Environment(\.dismiss) var dismiss
    var meeting: MeetingListModel
    @ObservedObject var meetingViewModel: MeetingViewModel
    @State private var title: String = "모임장소"
    @State private var showingAddFriendModal = false
    @State private var leaderSelctionModal = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showActionSheet = false
    @State private var showingEditMeetingModal = false
    @State private var showingKickOutModal = false

    var body: some View {
        NavigationStack {
            VStack {
                VStack(alignment: .leading) {
                    Text("모임날짜: \(formattedDate(date: meeting.date))")
                        .font(.headline)
                        .padding(.bottom, 5)
                    
                    if let masterName = meetingViewModel.meetingMemberNames[meeting.meetingMasterID] {
                        Text("모임장: \(masterName)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 50)
                    } else {
                        Text("모임장 정보를 불러오는 중...")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .padding(.bottom, 50)
                    }
                }
                .padding(.leading, -120)
                
                Text(title)
                    .font(.title2)
            
                
                MeetingMapView(
                    selectedUserLocation: $meetingViewModel.selectedUserLocation, // ViewModel의 selectedUserLocation 바인딩
                    meeting: MeetingModel(
                        id: meeting.id,
                        title: meeting.title,
                        date: meeting.date,
                        meetingAddress: meeting.meetingAddress,
                        meetingLocation: meeting.meetingLocation,
                        meetingMemberIDs: meeting.meetingMemberIDs,
                        meetingMasterID: meeting.meetingMasterID
                    ),
                    meetingViewModel: meetingViewModel
                )
                .frame(height: 300)
                
                Button(action: {
                    title = "모임장소"
                    meetingViewModel.stopTrackingMember() // 멤버 추적 중지
                    meetingViewModel.selectedUserLocation = meeting.meetingLocation // ViewModel의 selectedUserLocation 업데이트
                }) {
                    Text("모임장소")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                ForEach(0..<meeting.meetingMemberIDs.count / 3 + (meeting.meetingMemberIDs.count % 3 > 0 ? 1 : 0), id: \.self) { rowIndex in
                    HStack {
                        ForEach(0..<3) { columnIndex in
                            let index = rowIndex * 3 + columnIndex
                            if index < meeting.meetingMemberIDs.count {
                                let memberID = meeting.meetingMemberIDs[index]
                                
                                if let currentUserID = Auth.auth().currentUser?.uid, currentUserID != memberID {
                                    Button(action: {
                                        if meetingViewModel.trackedMemberID == memberID {
                                            title = (meetingViewModel.meetingMemberNames[memberID] ?? "멤버") + "의 위치 \n     추적 중지"
                                            meetingViewModel.stopTrackingMember()
                                        } else {
                                            title = (meetingViewModel.meetingMemberNames[memberID] ?? "멤버") + "의 위치 \n      추적 중"
                                            meetingViewModel.moveToUserLocation(userID: memberID)
                                        }
                                    }) {
                                        ZStack {
                                            Text(meetingViewModel.meetingMemberNames[memberID] ?? "멤버 불러오는 중 ...")
                                                .padding()
                                                .background(Color.blue)
                                                .foregroundColor(.white)
                                                .cornerRadius(10)
                                            
                                            if memberID == meeting.meetingMasterID {
                                                Image(systemName: "crown.fill")
                                                    .foregroundColor(.yellow)
                                                    .offset(x: 0, y: -40)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }
                    }
                }
            }
            .onDisappear{
                meetingViewModel.stopTrackingMember()
            }
            .navigationTitle(meeting.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            if let currentUserID = Auth.auth().currentUser?.uid {
                                if meetingViewModel.isMeetingMaster(meetingID: meeting.id, currentUserID: currentUserID, meetingMasterID: meeting.meetingMasterID){
                                    showingAddFriendModal = true
                                }
                                else {
                                    alertMessage = "모임장만 멤버 초대를 할 수 있습니다."
                                    showAlert = true
                                }

                            }
                        }) {
                            Image(systemName: "person.badge.plus")
                        }
                        
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
                var buttons: [ActionSheet.Button] = [
                    .destructive(Text("나가기")) {
                        meetingViewModel.leaveMeeting(meetingID: meeting.id)
                        dismiss()
                    },
                    .cancel(Text("취소"))
                ]
                
                if let currentUserID = Auth.auth().currentUser?.uid {
                    if meetingViewModel.isMeetingMaster(meetingID: meeting.id, currentUserID: currentUserID, meetingMasterID: meeting.meetingMasterID) {
                        buttons.insert(.default(Text("멤버 강퇴하기")) {
                            showingKickOutModal = true
                        }, at: 0)
                    } else {
                        buttons.insert(.default(Text("멤버 강퇴하기")) {
                            alertMessage = "모임장만 사용할 수 있는 기능입니다"
                            showAlert = true
                        }, at: 0)
                    }
                }
                
                if let currentUserID = Auth.auth().currentUser?.uid {
                    if meetingViewModel.isMeetingMaster(meetingID: meeting.id, currentUserID: currentUserID, meetingMasterID: meeting.meetingMasterID) {
                        buttons.insert(.default(Text("모임정보 수정")) {
                            showingEditMeetingModal = true
                        }, at: 0)
                    } else {
                        buttons.insert(.default(Text("모임 정보 수정")) {
                            alertMessage = "모임장만 사용할 수 있는 기능입니다"
                            showAlert = true
                        }, at: 0)
                    }
                }
                
                if let currentUserID = Auth.auth().currentUser?.uid {
                    if meetingViewModel.isMeetingMaster(meetingID: meeting.id, currentUserID: currentUserID, meetingMasterID: meeting.meetingMasterID) {
                        buttons.insert(.default(Text("모임장 변경")) {
                            leaderSelctionModal = true
                        }, at: 1)
                    } else {
                        buttons.insert(.default(Text("모임장 변경")) {
                            alertMessage = "모임장만 사용할 수 있는 기능입니다"
                            showAlert = true
                        }, at: 1)
                    }
                }
                
                // ActionSheet 반환
                return ActionSheet(
                    title: Text("모임 관리"),
                    message: Text("원하는 작업을 선택하세요."),
                    buttons: buttons
                )
            }
            .fullScreenCover(isPresented: $showingEditMeetingModal) {
                NavigationStack {
                    EditMeetingView(meetingID: meeting.id)
                }
            }
            .sheet(isPresented: $leaderSelctionModal) {
                LeaderSelectionView(meetingID: meeting.id, currentUserID: Auth.auth().currentUser?.uid ?? "")
            }
            .sheet(isPresented: $showingKickOutModal) {
                KickOutMember(meetingID: meeting.id, currentUserID: Auth.auth().currentUser?.uid ?? "")
            }
        }
    }
    private func formattedDate(date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
            return formatter.string(from: date)
        }
}

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
    @State var meetingDate: Date? = nil
    @State private var showingAddFriendModal = false
    @State private var leaderSelctionModal = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showActionSheet = false
    @State private var showingEditMeetingModal = false
    @State private var showingKickOutModal = false
    @State private var selectedMemberID: String? = nil 
    @State private var selectedButton: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(meetingViewModel.meetingDate != nil ? formattedDate(meetingViewModel.meetingDate!) : "모임시간: 불러오는 중...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
                .padding(.bottom, 10)
                
                MeetingMapView(
                    selectedUserLocation: $meetingViewModel.selectedUserLocation,
                    meeting: MeetingModel(
                        id: meeting.id,
                        title: meeting.title,
                        date: meeting.date,
                        meetingAddress: meeting.meetingAddress,
                        meetingLocation: meeting.meetingLocation,
                        meetingMemberIDs: meeting.meetingMemberIDs,
                        meetingMasterID: meeting.meetingMasterID,
                        isLocationTrackingEnabled: meeting.isLocationTrackingEnabled
                    ),
                    meetingViewModel: meetingViewModel
                )
                .frame(height: 450)
                
                Button(action: {
                    meetingViewModel.stopTrackingMember()
                    meetingViewModel.selectedUserLocation = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        meetingViewModel.selectedUserLocation = meeting.meetingLocation
                    }

                    selectedMemberID = nil
                    selectedButton = "meetingLocation"
                }) {
                    Text("모임장소")
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedButton == "meetingLocation" ? Color.yellow : Color.clear, lineWidth: 4)
                        )
                }

                
                
                ScrollView(.horizontal, showsIndicators: false) {
                                  LazyHStack(spacing: 16) {
                                      ForEach(meeting.meetingMemberIDs, id: \.self) { memberID in
                                          Button(action: {
                                              if meetingViewModel.trackedMemberID == memberID {
                                                  meetingViewModel.stopTrackingMember()
                                                  selectedMemberID = nil
                                              } else {
                                                  meetingViewModel.moveToUserLocation(userID: memberID)
                                                  selectedMemberID = memberID
                                              }
                                              selectedButton = memberID // 멤버 버튼 선택 상태로 설정
                                          }) {
                                              ZStack {
                                                  Text(meetingViewModel.meetingMemberNames[memberID] ?? "멤버 불러오는 중 ...")
                                                      .padding()
                                                      .background(Color.blue)
                                                      .foregroundColor(.white)
                                                      .cornerRadius(10)
                                                      .overlay(
                                                          RoundedRectangle(cornerRadius: 10)
                                                              .stroke(selectedMemberID == memberID ? Color.yellow : Color.clear, lineWidth: 4) // 노란색 테두리
                                                      )
                                                  
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
                                  .padding(.horizontal)
                    .padding(.horizontal)
                }
            }
            .onAppear {
                meetingViewModel.fetchMeetingData(meetingID: meeting.id)
            }
            .onDisappear {
                meetingViewModel.stopTrackingMember()
            }
            .navigationTitle(meeting.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            if let currentUserID = Auth.auth().currentUser?.uid {
                                if meetingViewModel.isMeetingMaster(meetingID: meeting.id, currentUserID: currentUserID, meetingMasterID: meeting.meetingMasterID) {
                                    showingAddFriendModal = true
                                } else {
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
        
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        return "모임시간: \(formatter.string(from: date))"
    }
}

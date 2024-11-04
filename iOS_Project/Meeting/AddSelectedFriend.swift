//
//  AddSelectedFriend.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/31/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct AddSelectedFriend: View {
    @ObservedObject var friendListViewModel = FriendListViewModel()
    var meeting: MeetingListModel
    
    @State private var selectedFriends: [String] = []
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack {
                    if friendListViewModel.friends.isEmpty {
                        Text("친구 목록이 없습니다.")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List(friendListViewModel.friends) { friend in
                            FriendRow(friend: friend, isSelected: selectedFriends.contains(friend.id)) {
                                toggleSelection(for: friend)
                            }
                        }
                    }
                }
                .onAppear {
                    friendListViewModel.observeFriends()
                }
                .navigationTitle("멤버 추가")
                
                Button(action: sendMeetingInvitations) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                        .padding(.bottom, 20)
                        .padding(.trailing, 20)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인"), action: {
                    // 알림이 닫힐 때 모달도 닫기
                    presentationMode.wrappedValue.dismiss()
                }))
            }
        }
    }
    
    func toggleSelection(for friend: FriendModel) {
        if let index = selectedFriends.firstIndex(of: friend.id) {
            selectedFriends.remove(at: index)
        } else {
            selectedFriends.append(friend.id)
        }
    }
    
    func sendMeetingInvitations() {
        guard let currentUserID = Auth.auth().currentUser?.uid,
              let currentUserName = friendListViewModel.currentUserName else { return }
        
        let db = Firestore.firestore()
        var failedInvitations = [String]()
        let totalFriendsCount = selectedFriends.count
        var completedRequests = 0 // 요청 완료된 수
    
        for friendID in selectedFriends {
            // 이미 보낸 요청이 있는지 확인
            db.collection("meetingRequests")
                .whereField("fromUserID", isEqualTo: currentUserID)
                .whereField("toUserID", isEqualTo: friendID)
                .whereField("meetingName", isEqualTo: meeting.title)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("요청 확인 중 오류 발생: \(error)")
                        return
                    }
                    
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        // 이미 요청이 있는 경우
                        alertMessage = "모임 요청을 이미 보낸 상태입니다."
                        showAlert = true
                    } else {
                        // 요청이 없는 경우 새 요청 생성
                        let invitationData: [String: Any] = [
                            "fromUserID": currentUserID,
                            "fromUserName": currentUserName,
                            "toUserID": friendID,
                            "meetingName": meeting.title,
                            "status": "pending",
                            "meetingID": meeting.id
                        ]
                        db.collection("meetingRequests").addDocument(data: invitationData) { error in
                            if let error = error {
                                print("모임 초대 요청 전송 실패: \(error)")
                                failedInvitations.append(friendID)
                            } else {
                                print("\(friendID)에게 모임 초대 요청 성공적으로 전송")
                            }
                            
                            completedRequests += 1 // 요청 완료 수 증가
                            
                            // 모든 요청이 완료된 후 알림 메시지 설정
                            if completedRequests == totalFriendsCount {
                                if failedInvitations.isEmpty {
                                    alertMessage = "모임 초대 요청이 성공적으로 전송되었습니다!"
                                } else {
                                    alertMessage = "\(failedInvitations.count)명에게 초대 요청 전송에 실패했습니다."
                                }
                                showAlert = true
                            }
                        }
                    }
                }
        }
    }
}

struct FriendRow: View {
    var friend: FriendModel
    var isSelected: Bool
    var onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(friend.name).font(.headline)
            Text(friend.email).font(.subheadline)
            Text("Phone: \(friend.phoneNumber)")
            Text("Birthday: \(friend.birthday)")
        }
        .padding()
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}

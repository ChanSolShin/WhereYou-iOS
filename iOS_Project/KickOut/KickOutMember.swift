//
//  KickOutMember.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/14/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct KickOutMember: View {
    @Environment(\.dismiss) var dismiss
    var meetingID: String
    var currentUserID: String
    @StateObject private var viewModel = KickOutMemberViewModel()
    @State private var selectedMember: User?
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        VStack {
            Text("멤버 강퇴하기")
                .font(.headline)
            
            if viewModel.isLoading {
                Text("멤버 불러오는 중...")
                    .padding()
            } else {
                List(viewModel.members.filter { $0.id != currentUserID }) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        if selectedMember?.id == member.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .onTapGesture {
                        // 이미 선택된 멤버가 다시 탭되면 선택 해제
                        if selectedMember?.id == member.id {
                            selectedMember = nil
                        } else {
                            selectedMember = member
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                if let member = selectedMember {
                    viewModel.kickOutMember(meetingID: meetingID, memberID: member.id) { result in
                        switch result {
                        case .success:
                            alertMessage = "\(member.name) 님을 성공적으로 강퇴했습니다."
                            showAlert = true
                        case .failure(let error):
                            alertMessage = "강퇴에 실패했습니다: \(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                }
            }) {
                Text("강퇴하기")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .foregroundColor(.white)
                    .background(selectedMember != nil ? Color.blue : Color.gray)
                    .cornerRadius(8)
            }
            .disabled(selectedMember == nil) // 선택된 멤버가 없으면 버튼 비활성화
        }
        .padding()
        .onAppear {
            viewModel.fetchMeetingMembers(meetingID: meetingID)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인"), action: {
                    dismiss()
                })
            )
        }
    }
}

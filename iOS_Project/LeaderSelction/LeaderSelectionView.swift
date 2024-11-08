//
//  LeaderSelectionView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import SwiftUI
import Firebase

struct LeaderSelectionView: View {
    @Environment(\.dismiss) var dismiss
    var meetingID: String
    var currentUserID: String
    @StateObject private var viewModel = LeaderSelectionViewModel() // ViewModel 사용
    @State private var selectedLeader: User?
    @State private var meeting: MeetingModel? // meeting 모델 상태 추가
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""

    func updateLeader() {
        guard let newLeader = selectedLeader else { return }
        
        let db = Firestore.firestore()
        
        // 모임의 leaderID를 새로 선택된 리더로 업데이트
        db.collection("meetings").document(meetingID).updateData([
            "meetingMaster": newLeader.id
        ]) { error in
            if let error = error {
                print("모임장 변경 실패: \(error.localizedDescription)")
            } else {
                // Firestore 업데이트가 성공하면 로컬 모델에서도 meetingMaster 업데이트
                meeting?.meetingMasterID = newLeader.id
                print("모임장 변경 성공")
                alertMessage = "모임장을 변경했습니다!"
                showAlert = true
            }
        }
    }

    var body: some View {
        VStack {
            Text("모임장 변경")
                .font(.headline)
            
            // 로딩 중이라면 로딩 텍스트 표시
            if viewModel.isLoading {
                Text("멤버 불러오는 중...")
                    .padding()
            } else {
                List(viewModel.members.filter { $0.id != currentUserID }) { member in
                    HStack {
                        Text(member.name)
                        Spacer()
                        if selectedLeader?.id == member.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .onTapGesture {
                        // 리더를 선택하거나 선택 해제
                        if selectedLeader?.id == member.id {
                            selectedLeader = nil
                        } else {
                            selectedLeader = member
                        }
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                // 완료 버튼 클릭 시 모임장 업데이트
                updateLeader()
            }) {
                Text("변경하기")
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(selectedLeader != nil ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(selectedLeader == nil)
        }
        .padding()
        .onAppear {
            // 모임의 멤버를 불러오기
            viewModel.fetchMeetingMembers(meetingID: meetingID)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("알림"),
                message: Text(alertMessage),
                dismissButton: .default(Text("확인"), action: {
                    dismiss() // 확인 버튼을 누르면 dismiss 실행
                })
            )
        }
    }
}

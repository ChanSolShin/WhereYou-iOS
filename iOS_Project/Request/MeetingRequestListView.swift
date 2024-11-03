//
//  MeetingRequestListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/31/24.
//

import SwiftUI

struct MeetingRequestListView: View {
    @ObservedObject var viewModel: MeetingViewModel

    var body: some View {
        VStack {
            if viewModel.pendingMeetingRequests.isEmpty {
                Text("받은 모임 초대가 없습니다.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List {
                    ForEach(viewModel.pendingMeetingRequests) { request in
                        HStack {
                            Spacer()
                            VStack {
                                Text("\(request.fromUserName)님이 \(request.meetingName) 에 초대하였습니다.")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .padding(.bottom, 5)
                                HStack(spacing: 30) {
                                    Button("수락") {
                                        acceptRequest(request)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    
                                    Button("거절") {
                                        rejectRequest(request)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green, lineWidth: 2)
                        )
                    }
                }
            }
        }
        .navigationTitle("모임 요청 목록")
        .onAppear {
            viewModel.fetchPendingMeetingRequests()
        }
    }
    
    private func acceptRequest(_ request: MeetingRequestModel) {
        viewModel.acceptMeetingRequest(requestID: request.id, fromUserID: request.fromUserID)
        
        // 요청 삭제 후 UI 업데이트
        deleteRequest(request)
    }
    
    private func rejectRequest(_ request: MeetingRequestModel) {
        viewModel.rejectMeetingRequest(requestID: request.id)
        
        // 요청 삭제 후 UI 업데이트
        deleteRequest(request)
    }
    
    private func deleteRequest(_ request: MeetingRequestModel) {
        if let index = viewModel.pendingMeetingRequests.firstIndex(where: { $0.id == request.id }) {
            viewModel.pendingMeetingRequests.remove(at: index)
        }
    }
}

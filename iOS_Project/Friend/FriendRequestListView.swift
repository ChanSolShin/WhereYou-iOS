//
//  FriendRequestListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/29/24.
//

import SwiftUI

struct FriendRequestListView: View {
    @ObservedObject var viewModel: FriendListViewModel

    var body: some View {
        VStack {
            if viewModel.pendingRequests.isEmpty {
                // 친구 요청이 없을 때 표시할 텍스트
                Text("받은 친구 요청이 없습니다.")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else {
                // 친구 요청이 있을 경우 List 표시
                List {
                    ForEach(viewModel.pendingRequests) { request in
                        HStack {
                            Spacer()
                            VStack {
                                Text(request.fromUserName)
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
        .navigationTitle("친구 요청 목록")
        .onAppear {
            viewModel.fetchPendingRequests()
        }
    }
    
    private func acceptRequest(_ request: FriendRequestModel) {
        viewModel.acceptFriendRequest(requestID: request.id, fromUserID: request.fromUserID)
        
        // 친구 목록 갱신
        viewModel.observeFriends()
        
        // 요청 삭제 후 UI 업데이트
        deleteRequest(request)
    }
    
    private func rejectRequest(_ request: FriendRequestModel) {
        viewModel.rejectFriendRequest(requestID: request.id)
        
        // 요청 삭제 후 UI 업데이트
        deleteRequest(request)
    }
    
    private func deleteRequest(_ request: FriendRequestModel) {
        if let index = viewModel.pendingRequests.firstIndex(where: { $0.id == request.id }) {
            viewModel.pendingRequests.remove(at: index)
        }
    }
}

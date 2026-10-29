//
//  MeetingRequestListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/31/24.
//

import SwiftUI

struct MeetingRequestListView: View {
    @ObservedObject var viewModel: MeetingViewModel
    @State private var acceptingRequestIDs: Set<String> = []
    @State private var acceptError: String?

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
                                    Button {
                                        acceptRequest(request)
                                    } label: {
                                        if acceptingRequestIDs.contains(request.id) {
                                            ProgressView().accessibilityLabel("초대 수락 중")
                                        } else {
                                            Text("수락")
                                        }
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                    .disabled(acceptingRequestIDs.contains(request.id))
                                    
                                    Button("거절") {
                                        rejectRequest(request)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                            }
                            Spacer()
                        }
                        .padding()
                        .glassSurface(radius: 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GlassBackdrop())
        .navigationTitle("모임 요청")
        .onAppear {
            viewModel.fetchPendingMeetingRequests()
        }
        .alert("초대 수락 실패", isPresented: Binding(
            get: { acceptError != nil },
            set: { if !$0 { acceptError = nil } }
        )) {
            Button("확인", role: .cancel) { acceptError = nil }
        } message: {
            Text(acceptError ?? "다시 시도해 주세요.")
        }
    }
    
    private func acceptRequest(_ request: MeetingRequestModel) {
        guard acceptingRequestIDs.insert(request.id).inserted else { return }
        viewModel.acceptMeetingRequest(requestID: request.id) { result in
            acceptingRequestIDs.remove(request.id)
            if case .failure(let error) = result {
                acceptError = error.localizedDescription
            }
            // 성공하면 pending 리스너에서 목록이 자동으로 갱신된다.
        }
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

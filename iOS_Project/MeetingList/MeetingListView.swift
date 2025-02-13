import SwiftUI
import NMapsMap

struct MeetingListView: View {
    @ObservedObject private var viewModel = MeetingListViewModel()
    @State private var searchText = "" // 검색 텍스트
    @Binding var isTabBarHidden: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    if viewModel.meetings.isEmpty {
                        VStack {
                            Spacer()
                            Text("+ 버튼을 눌러서 새로운 모임을 생성하세요!")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding()
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(viewModel.meetings.filter { meeting in
                                    searchText.isEmpty || meeting.title.localizedCaseInsensitiveContains(searchText)
                                }) { meeting in
                                    NavigationLink(destination: MeetingView(meeting: meeting, meetingViewModel: viewModel.meetingViewModel)
                                        .onAppear { isTabBarHidden = true }
                                        .onDisappear { isTabBarHidden = false }
                                    ) {
                                        HStack {
                                            Text(meeting.title)
                                                .font(.headline)
                                                .padding()
                                                .foregroundColor(.black)
                                            Spacer()
                                            VStack(alignment: .trailing) {
                                                Text("\(meeting.date, formatter: dateFormatter)")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                Text(meeting.meetingAddress)
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                Text("\(meeting.meetingMemberIDs.count)명")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                        }
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .shadow(radius: 2)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.blue, lineWidth: 2)
                                        )
                                    }
                                    Divider()
                                        .padding(.vertical, 2)
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 10)
                    }
                }
                
                // + 버튼을 화면 오른쪽 하단에 고정
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        NavigationLink(destination: AddMeetingView(viewModel: AddMeetingViewModel())
                            .onAppear { isTabBarHidden = true }
                            .onDisappear { isTabBarHidden = false }
                        ) {
                            Image(systemName: "plus")
                                .font(.largeTitle)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.bottom, 20)
                        .padding(.trailing, 20)
                    }
                }
            }
            .navigationTitle("모임")
            .searchable(text: $searchText, prompt: "검색어를 입력하세요")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: MeetingRequestListView(viewModel: viewModel.meetingViewModel)
                        .onAppear { isTabBarHidden = true }
                        .onDisappear { isTabBarHidden = false }) {
                        HStack {
                            Image(systemName: "bell")
                            if viewModel.meetingViewModel.pendingMeetingRequests.count > 0 {
                                Text("\(viewModel.meetingViewModel.pendingMeetingRequests.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
            }
            .onAppear {
                // 대기 중인 요청을 실시간으로 받아오도록 설정
                viewModel.meetingViewModel.fetchPendingMeetingRequests()
            }
        }
    }
    
    // DateFormatter 정의
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

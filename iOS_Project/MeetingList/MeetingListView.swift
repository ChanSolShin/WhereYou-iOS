import SwiftUI

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingListViewModel()
    @StateObject private var addMeetingViewModel = AddMeetingViewModel()
    @ObservedObject private var meetingViewModel: MeetingViewModel
    @Binding var isTabBarHidden: Bool

    @EnvironmentObject var router: AppRouter
    @State private var openMeetingRequests = false
    @State private var isShowingMeetingRequests = false
    @State private var path = NavigationPath()

    init(isTabBarHidden: Binding<Bool>) {
        self._isTabBarHidden = isTabBarHidden
        self._meetingViewModel = ObservedObject(wrappedValue: MeetingViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            // Hidden link for meeting requests (deep link)
            NavigationLink(
                destination: MeetingRequestListView(viewModel: viewModel.meetingViewModel)
                    .onAppear {
                        isTabBarHidden = true
                        isShowingMeetingRequests = true
                    }
                    .onDisappear {
                        isTabBarHidden = false
                        isShowingMeetingRequests = false
                    },
                isActive: $openMeetingRequests
            ) { EmptyView() }
            .hidden()

            ZStack {
                VStack {
                    if viewModel.shouldShowBirthdayBanner, let name = viewModel.userProfile?.name {
                        HStack {
                            Text("\(name)님, 행복한 하루 되세요. 생일 축하합니다! 🥳")
                                .font(.headline)
                                .foregroundColor(.pink)
                            Spacer()
                            Button(action: viewModel.dismissBirthdayBanner) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.horizontal)
                    }

                    if viewModel.meetings.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Text("+ 버튼을 눌러서 새로운 모임을 생성하세요!")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(viewModel.filteredMeetings) { meeting in
                                    NavigationLink(
                                        destination: MeetingView(
                                            meeting: meeting,
                                            meetingViewModel: viewModel.meetingViewModel
                                        )
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
                                                Text("\(meeting.date, formatter: viewModel.listDateFormatter)")
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .overlay(
                NavigationLink(
                    destination: AddMeetingView(viewModel: addMeetingViewModel)
                        .onAppear { isTabBarHidden = true }
                        .onDisappear {
                            isTabBarHidden = false
                            addMeetingViewModel.meeting = AddMeetingModel()
                        }
                ) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 40),
                alignment: .bottomTrailing
            )
            .navigationTitle("모임")
            .searchable(text: $viewModel.searchText, prompt: "검색어를 입력하세요")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: MeetingRequestListView(viewModel: viewModel.meetingViewModel)
                            .onAppear {
                                isTabBarHidden = true
                                isShowingMeetingRequests = true
                            }
                            .onDisappear {
                                isTabBarHidden = false
                                isShowingMeetingRequests = false
                            }
                    ) {
                        HStack {
                            Image(systemName: "bell")
                            if viewModel.pendingRequestCount > 0 {
                                Text("\(viewModel.pendingRequestCount)")
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
            .navigationDestination(for: String.self) { id in
                if let meeting = viewModel.meetings.first(where: { $0.id == id }) {
                    MeetingView(meeting: meeting, meetingViewModel: viewModel.meetingViewModel)
                        .onAppear { isTabBarHidden = true }
                        .onDisappear { isTabBarHidden = false }
                } else {
                    ProgressView("모임 정보를 불러오는 중...")
                        .onAppear {
                            viewModel.fetchMeeting(by: id) { model in
                                if let model = model {
                                    DispatchQueue.main.async {
                                        viewModel.appendMeeting(model)
                                        path.append(model.id)
                                    }
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
        .onReceive(router.$pendingRoute) { dest in
            guard let dest = dest else { return }
            switch dest {
            case .meetingRequests:
                if !isShowingMeetingRequests && !openMeetingRequests {
                    openMeetingRequests = true
                }
                // 상태 초기화를 위해 consume은 항상 수행
                DispatchQueue.main.async {
                    router.consume(.meetingRequests)
                }
            case .meeting(let id):
                // ViewModel에 의도 전달 → 데이터 준비 → View에서 push
                viewModel.openMeeting(id: id)
                DispatchQueue.main.async {
                    router.consume(dest)
                }
            default:
                break
            }
        }
        .onReceive(viewModel.$meetingToOpenID.compactMap { $0 }) { id in
            // 데이터 준비가 끝났으므로 실제 네비게이션 수행
            path.append(id)
            // 1회성 이벤트 소모
            viewModel.meetingToOpenID = nil
        }
    }

    /// External entry for programmatic navigation if needed
    func navigateToMeeting(meetingId: String) {
        if let found = viewModel.meetings.first(where: { $0.id == meetingId }) {
            path.append(found.id)
        } else {
            viewModel.fetchMeeting(by: meetingId) { model in
                if let model = model {
                    DispatchQueue.main.async {
                        viewModel.appendMeeting(model)
                        path.append(model.id)
                    }
                }
            }
        }
    }
}

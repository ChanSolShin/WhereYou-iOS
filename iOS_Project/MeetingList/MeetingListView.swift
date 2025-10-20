import SwiftUI
import FirebaseFirestore
import CoreLocation

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingListViewModel()
    @ObservedObject private var meetingViewModel: MeetingViewModel
    @State private var searchText = "" // 검색 텍스트
    @Binding var isTabBarHidden: Bool
    @State private var isBirthdayMessageVisible = true

    @EnvironmentObject var router: AppRouter
    @State private var openMeetingRequests = false
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
                    .onAppear { isTabBarHidden = true }
                    .onDisappear { isTabBarHidden = false },
                isActive: $openMeetingRequests
            ) { EmptyView() }
            .hidden()

            ZStack {
                VStack {
                    if viewModel.isTodayUserBirthday(), isBirthdayMessageVisible {
                        if let name = viewModel.userProfile?.name {
                            HStack {
                                Text("\(name)님, 행복한 하루 되세요. 생일 축하합니다! 🥳")
                                    .font(.headline)
                                    .foregroundColor(.pink)
                                Spacer()
                                Button(action: { isBirthdayMessageVisible = false }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                        }
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
                                ForEach(viewModel.meetings.filter { meeting in
                                    searchText.isEmpty || meeting.title.localizedCaseInsensitiveContains(searchText)
                                }) { meeting in
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .overlay(
                NavigationLink(
                    destination: AddMeetingView(viewModel: AddMeetingViewModel())
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
                .padding(.trailing, 20)
                .padding(.bottom, 40),
                alignment: .bottomTrailing
            )
            .navigationTitle("모임")
            .searchable(text: $searchText, prompt: "검색어를 입력하세요")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(
                        destination: MeetingRequestListView(viewModel: viewModel.meetingViewModel)
                            .onAppear { isTabBarHidden = true }
                            .onDisappear { isTabBarHidden = false }
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
                            fetchMeeting(by: id) { model in
                                if let model = model {
                                    viewModel.meetings.append(model)
                                    path.append(model.id)
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
                openMeetingRequests = true
                // 네비게이션 푸시가 완료된 후 상태 초기화를 위해 지연
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    router.consume(.meetingRequests)
                }

            case .meeting:
                // MeetingView 딥링크 보류: 네비게이션 수행 없이 consume만 처리
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    router.consume(dest)
                }

            default:
                break
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

    // MARK: - Deep Link Helpers
    private func fetchMeeting(by id: String, completion: @escaping (MeetingListModel?) -> Void) {
        let db = Firestore.firestore()
        db.collection("meetings").document(id).getDocument { snap, error in
            guard error == nil, let doc = snap, doc.exists, let data = doc.data() else {
                completion(nil)
                return
            }
            guard
                let title = data["meetingName"] as? String,
                let ts = data["meetingDate"] as? Timestamp,
                let address = data["meetingAddress"] as? String,
                let gp = data["meetingLocation"] as? GeoPoint,
                let members = data["meetingMembers"] as? [String],
                let master = data["meetingMaster"] as? String,
                let tracking = data["isLocationTrackingEnabled"] as? Bool
            else {
                completion(nil)
                return
            }
            let model = MeetingListModel(
                id: doc.documentID,
                title: title,
                date: ts.dateValue(),
                meetingAddress: address,
                meetingLocation: CLLocationCoordinate2D(latitude: gp.latitude, longitude: gp.longitude),
                meetingMemberIDs: members,
                meetingMasterID: master,
                isLocationTrackingEnabled: tracking
            )
            completion(model)
        }
    }

    /// External entry for programmatic navigation if needed
    func navigateToMeeting(meetingId: String) {
        if let found = viewModel.meetings.first(where: { $0.id == meetingId }) {
            path.append(found.id)
        } else {
            fetchMeeting(by: meetingId) { model in
                if let model = model { path.append(model.id) }
            }
        }
    }
}

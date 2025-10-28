import SwiftUI
import Foundation

enum FriendRoute: Hashable {
    case friendRequests
}

struct FriendListView: View {
    @StateObject var viewModel = FriendListViewModel()
    @State private var showAddFriendModal = false
    @Binding var isTabBarHidden: Bool
    @State private var addFriendType: AddFriendType?
    @State private var showAddFriendActionSheet = false
    @EnvironmentObject var router: AppRouter
    @State private var path = NavigationPath()
    @State private var isShowingFriendRequests = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color.white.ignoresSafeArea()
                VStack {
                    if viewModel.friends.isEmpty {
                        Text("+ 버튼을 눌러서 새로운 친구를 추가하세요!")
                            .font(.headline)
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        List {
                            ForEach(viewModel.friends) { friend in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(friend.name)
                                            .font(.headline)
                                        Text(friend.email)
                                            .font(.subheadline)
                                        Text("Phone: \(friend.phoneNumber)")
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                }
                                .swipeActions {
                                    Button {
                                        viewModel.removeFriend(friendID: friend.id)
                                    } label: {
                                        Text("삭제")
                                    }
                                    .tint(.red)
                                }
                            }
                            .onDelete(perform: deleteFriend)
                        }
                        .listStyle(PlainListStyle())
                        .background(Color.clear)
                    }
                }
            }
            .background(Color.white.edgesIgnoringSafeArea(.all))
            .navigationTitle("친구")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        path.append(FriendRoute.friendRequests)
                        isTabBarHidden = true
                    } label: {
                        HStack {
                            Image(systemName: "bell")
                            if viewModel.pendingRequests.count > 0 {
                                Text("\(viewModel.pendingRequests.count)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.red)
                                    .clipShape(Circle())
                            }
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddFriendActionSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .confirmationDialog("친구 추가", isPresented: $showAddFriendActionSheet, titleVisibility: .visible) {
                Button("이메일로 친구 추가") { addFriendType = .email }
                Button("전화번호로 친구 추가") { addFriendType = .phone }
                Button("취소", role: .cancel) {}
            }
            .sheet(item: $addFriendType) { type in
                switch type {
                case .email:
                    AddFriendEmailModal(viewModel: viewModel, isPresented: Binding(get: { addFriendType != nil }, set: { _ in addFriendType = nil }))
                case .phone:
                    AddFriendNumberModal(viewModel: viewModel, isPresented: Binding(get: { addFriendType != nil }, set: { _ in addFriendType = nil }))
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("알림"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("확인")))
            }
            .navigationDestination(for: FriendRoute.self) { route in
                switch route {
                case .friendRequests:
                    FriendRequestListView(viewModel: viewModel)
                        .onAppear {
                            isTabBarHidden = true
                            isShowingFriendRequests = true
                        }
                        .onDisappear {
                            isTabBarHidden = false
                            isShowingFriendRequests = false
                        }
                }
            }
            .onReceive(router.$pendingRoute) { dest in
                guard let dest = dest else { return }
                switch dest {
                case .friendRequests:
                    if !isShowingFriendRequests {
                        path.append(FriendRoute.friendRequests)
                    }
                    router.consume(.friendRequests)
                    isTabBarHidden = true
                default:
                    break
                }
            }
        }
    }

    private func deleteFriend(at offsets: IndexSet) {
        offsets.forEach { index in
            let friendToDelete = viewModel.friends[index]
            viewModel.removeFriend(friendID: friendToDelete.id)
        }
    }
}

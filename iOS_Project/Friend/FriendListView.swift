import SwiftUI
import Foundation

struct FriendListView: View {
    @StateObject private var viewModel = FriendListViewModel()
    @Binding var isTabBarHidden: Bool
    @State private var addFriendType: AddFriendType?
    @State private var showAddFriendAlert = false
    @EnvironmentObject var router: AppRouter
    @State private var openFriendRequests = false

    var body: some View {
        NavigationStack {
            ZStack {
                NavigationLink(
                    destination: friendRequestsDestination,
                    isActive: $openFriendRequests
                ) { EmptyView() }
                .hidden()

                GlassBackdrop()
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
                                .padding(12)
                                .glassSurface(radius: 12)
                                .swipeActions {
                                    Button {
                                        viewModel.removeFriend(friendID: friend.id)
                                    } label: {
                                        Text("삭제")
                                    }
                                    .tint(.red)
                                }
                                .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                            .onDelete(perform: deleteFriend)
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("친구")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .glassBarBackdrop()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        openFriendRequests = true
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
                    Button(action: { showAddFriendAlert = true }) {
                        Image(systemName: "plus")
                    }
                    .alert("친구 추가", isPresented: $showAddFriendAlert) {
                        Button("이메일로 추가") { presentEmailModal() }
                        Button("전화번호로 추가") { presentPhoneModal() }
                        Button("취소", role: .cancel) {}
                    } message: {
                        Text("추가 방법을 선택해 주세요")
                    }
                }
            }
            .sheet(item: $addFriendType) { type in
                switch type {
                case .email:
                    AddFriendEmailModal(
                        viewModel: viewModel,
                        isPresented: Binding(
                            get: { addFriendType != nil },
                            set: { _ in addFriendType = nil }
                        )
                    )
                case .phone:
                    AddFriendNumberModal(
                        viewModel: viewModel,
                        isPresented: Binding(
                            get: { addFriendType != nil },
                            set: { _ in addFriendType = nil }
                        )
                    )
                }
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(
                    title: Text("알림"),
                    message: Text(viewModel.alertMessage),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
        .background(GlassBackdrop())
        .onAppear {
            viewModel.observePendingRequests()
        }
        .onReceive(router.$pendingRoute) { dest in
            guard let dest = dest else { return }
            switch dest {
            case .friendRequests:
                openFriendRequests = true
                router.consume(.friendRequests)
            default:
                break
            }
        }
        .onReceive(router.$popToRootTab) { tab in
            guard let tab = tab else { return }
            if tab == .friend {
                openFriendRequests = false
                router.consumePop(for: .friend)
            }
        }
    }

    @MainActor
    private func deleteFriend(at offsets: IndexSet) {
        offsets.forEach { index in
            let friendToDelete = viewModel.friends[index]
            viewModel.removeFriend(friendID: friendToDelete.id)
        }
    }

    @MainActor
    private func presentEmailModal() {
        viewModel.resetFriendEmailInput()
        addFriendType = .email
    }

    @MainActor
    private func presentPhoneModal() {
        viewModel.resetFriendPhoneInput()
        addFriendType = .phone
    }

    @MainActor
    private var friendRequestsDestination: some View {
        FriendRequestListView(viewModel: viewModel)
            .onAppear { isTabBarHidden = true }
            .onDisappear { isTabBarHidden = false }
    }
}

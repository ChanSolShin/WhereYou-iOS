import SwiftUI
import Foundation

struct FriendListView: View {
    @ObservedObject var viewModel = FriendListViewModel()
    @State private var showAddFriendModal = false
    @Binding var isTabBarHidden: Bool
    @State private var addFriendType: AddFriendType? // Added this line
    @State private var showAddFriendActionSheet = false

    var body: some View {
        NavigationView {
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
                                        Text("Birthday: \(friend.birthday)")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
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
                          NavigationLink(destination: FriendRequestListView(viewModel: viewModel)
                              .onAppear { isTabBarHidden = true }
                              .onDisappear { isTabBarHidden = false }) {
                              HStack {
                                  Image(systemName: "bell")
                                  if viewModel.pendingRequests.count > 0 { // 요청이 온 수 만큼 숫자로 표시
                                      Text("\(viewModel.pendingRequests.count)")
                                          .font(.caption)
                                          .foregroundColor(.white)
                                          .padding(3)
                                          .background(Color.red)
                                          .clipShape(Circle())
                                  }
                              }
                          }
                          Button(action: { showAddFriendActionSheet = true }) {
                              Image(systemName: "plus")
                          }
                      }
            .confirmationDialog("친구 추가", isPresented: $showAddFriendActionSheet, titleVisibility: .visible) {
                Button("이메일로 친구 추가") {
                    addFriendType = .email
                }
                Button("전화번호로 친구 추가") {
                    addFriendType = .phone
                }
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
        }
        .onAppear {
            viewModel.observePendingRequests() // 친구 요청 목록 업데이트
        }
    }
    
    private func deleteFriend(at offsets: IndexSet) {
        offsets.forEach { index in
            let friendToDelete = viewModel.friends[index]
            viewModel.removeFriend(friendID: friendToDelete.id)
        }
    }
}

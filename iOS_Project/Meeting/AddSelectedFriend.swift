//
//  AddSelectedFriend.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/31/24.
//

import SwiftUI

struct AddSelectedFriend: View {
    @ObservedObject var viewModel: FriendListViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedFriends: [String] = []

    var body: some View {
        NavigationView {
            VStack {
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
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedFriends.contains(friend.id) ? Color.blue : Color.clear, lineWidth: 2) // 선택된 친구 테두리 강조
                        )
                        .onTapGesture {
                            toggleFriendSelection(friend: friend) // 친구 선택/해제
                        }
                    }
                }
                .navigationTitle("친구 목록")
                .navigationBarItems(trailing: Button("닫기") {
                    dismiss()
                })
                
                Spacer()

                Button(action: {
                    // 친구 추가 동작 처리 (추가 로직 구현 필요)
                }) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                        .padding(.bottom, 20)                        
                }
                .padding(.bottom, 20)
            }
        }
    }

    // 친구 선택/해제 처리
    private func toggleFriendSelection(friend: FriendModel) {
        if let index = selectedFriends.firstIndex(of: friend.id) {
            selectedFriends.remove(at: index) // 이미 선택된 친구면 제거
        } else {
            selectedFriends.append(friend.id) // 선택되지 않은 친구면 추가
        }
    }
}

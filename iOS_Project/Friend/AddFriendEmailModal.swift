//
//  AddFriendEmailModal.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/29/24.
//

import SwiftUI

struct AddFriendEmailModal: View {
    @ObservedObject var viewModel: FriendListViewModel
    @Binding var isPresented: Bool
    @State private var friendEmail = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("추가할 친구의 이메일을 입력해 주세요")
            TextField("이메일", text: $friendEmail)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .keyboardType(.emailAddress)
            Button(action: {
                viewModel.sendFriendRequest(toEmail: friendEmail)
                isPresented = false
            }) {
                Text("친구 요청 보내기")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(friendEmail.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(friendEmail.isEmpty) 
            .padding(.horizontal)
        }
        .padding()
    }
}

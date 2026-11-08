//
//  FindPasswordView.swift
//  iOS_Project
//
//  Created by CHOI on 10/31/24.
//

import SwiftUI

struct FindPasswordView: View {
    @StateObject private var viewModel = FindPasswordViewModel()
    @State private var showAlert = false
    
    var body: some View {
        ScrollView {
            VStack {
                
                Text("웨어유")
                    .font(.largeTitle)
                    .padding(.bottom, 180)
                    .padding(.top,20)
                    .fontWeight(.bold)
                Spacer()                
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    TextField("이메일을 입력하세요", text: $viewModel.model.email)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                .padding()
                .glassSurface(radius: 8)
                .padding(.horizontal)
                
                Button(action: {
                    viewModel.resetPassword {
                        showAlert = true
                    }
                }) {
                    Text("비밀번호 재설정")
                        .frame(width: 200, height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.top, 20)
                }
                .alert(isPresented: $showAlert) {
                    Alert(title: Text("알림"), message: Text(viewModel.errorMessage ?? "비밀번호 재설정 이메일이 발송되었습니다."))
                }

                // 소셜 로그인 계정은 비밀번호가 없어 재설정 메일이 발송되지 않음
                Text("Apple, Google 등 소셜 로그인으로 가입한 계정은 비밀번호가 없어요.\n로그인 화면에서 가입한 방식으로 로그인해 주세요.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
                    .padding(.horizontal, 30)
            }
        }
        .background(GlassBackdrop())
        .navigationTitle("비밀번호 재설정")
    }
}

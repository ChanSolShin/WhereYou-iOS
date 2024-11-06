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
                
                Text("MyApp")
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
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
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
            }
        }
        .navigationTitle("비밀번호 재설정")
    }
}

// 프리뷰용 코드
struct FindPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        FindPasswordView()
    }
}

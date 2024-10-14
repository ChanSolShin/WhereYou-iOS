//
//  LoginView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//


import SwiftUI

struct LoginView: View {
    
    @StateObject private var viewModel = LoginViewModel()
    @State private var showPassword = false
    @State private var isLoggedIn = false
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack {
                // 앱 이름 표시
                Text("MyApp")
                    .font(.largeTitle)
                    .padding(.top, 70)
                    .padding(.bottom, 70)
                // 이메일
                Text("Email address")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 25)
                    .font(.headline)
                    .padding(.horizontal, 10)
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                    TextField("이메일", text: $viewModel.user.username)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 30)
                
                // 비밀번호
                Text("Password")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 25)
                    .font(.headline)
                    .padding(.horizontal, 10)
                    .padding(.top,20)
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    SecureField("비밀번호", text: $viewModel.user.password)
                    Button(action: {
                        showPassword.toggle() // 비밀번호 가시성 토글
                    }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .imageScale(.medium)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
                
                // 로그인 및 회원가입 버튼
                HStack(spacing: 80) {
                    Button("로그인") {
                        viewModel.login() //Firebase 로그인
                        if viewModel.loginErrorMessage != nil{
                            showAlert = true // 로그인 실패 시, 알림창
                        }
                    }
                    .disabled(!viewModel.isValidEmail || viewModel.isPasswordEmpty)
                    // 이메일 형식이 맞지않거나, 패스워드가 비어있으면 로그인 버튼을 누를수 없음.
                    NavigationLink(destination: SignUpView()) {
                        Text("회원가입")
                    }
                }
                .padding(.horizontal, 40)
                Spacer()
            }
        }
        .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
            MainTabView() // 로그인 후 메인 화면으로 전환
            
                .alert(isPresented: $showAlert){
                    Alert(
                        title: Text("로그인 실패"),
                        message: Text(" 로그인에 실패하였습니다."),
                        dismissButton: .default(Text("확인"))
                    )
                }
        }
    }
}


// 프리뷰용 코드
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}


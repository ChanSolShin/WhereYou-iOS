//
//  LoginView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//


import SwiftUI
import NMapsMap

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
                    .padding(.top, 60)
                    .padding(.bottom, 10)
                    .fontWeight(.bold)
                
                // 이메일
                Text("로그인")
                    .font(.title2)
                    .padding(.bottom, 50)
                    .fontWeight(.bold)

                
                HStack {
                    Image(systemName: "person")
                        .foregroundColor(.gray)
                    TextField("이메일을 입력하세요", text: $viewModel.user.username)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 30)
                
                // 비밀번호
         
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    
                    if showPassword {
                        TextField("비밀번호번호를 입력하세요", text: $viewModel.user.password)
                            .font(.system(size: 16))
                            .autocapitalization(.none)
                    } else {
                        SecureField("비밀번호를 입력하세요", text: $viewModel.user.password)
                            .font(.system(size: 16))
                            .autocapitalization(.none)
                    }
                    
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
                .padding(.bottom, 5)
                
                
                Text("비밀번호 찾기") // 비밀번호 찾기 구현해야함.
                    .font(.system(size: 14))
                    .padding(.leading, 300)
                    .foregroundColor(.gray)
                    .underline()
                    .padding(.horizontal, 10)
                    .padding(.bottom, 20)
                
                // 로그인 및 회원가입 버튼
                NavigationLink(destination: MainTabView(), isActive: $viewModel.isLoggedIn) {
                    Button(action: {
                        viewModel.login()
                        showAlert = false
                    }) {
                        Text("이메일로 로그인") // 버튼에 표시할 텍스트
                            .frame(width: 350, height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .cornerRadius(40)
                    }
                    .contentShape(Rectangle())
                }
                .fullScreenCover(isPresented: $viewModel.isLoggedIn) {
                    MainTabView() // 로그인 성공 시 MainTabView로 전환
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("로그인 실패"),
                        message: Text("이메일 또는 비밀번호가 일치하지 않습니다."),
                        dismissButton: .default(Text("확인"))
                    )
                }
                .onChange(of: viewModel.loginErrorMessage) { errorMessage in
                    if errorMessage != nil {
                        showAlert = true // 로그인 실패 시 알림창 띄우기
                        viewModel.loginErrorMessage = nil // 알림창을 다시 띄울 수 있도록 loginErrorMessage 초기화
                    }
                }
                    .padding(.bottom,20)
                
                HStack {
                    NavigationLink(destination: SignUpView()) {
                        Text("회원가입")
                            .foregroundColor(.black)
                            .underline()
                    }
                    Text("|")
                        .foregroundColor(.gray)
                        .underline()
                        .padding(.horizontal, 15)
                    
                    Text("이메일 찾기") // 이메일찾기 구현해야함
                        .foregroundColor(.black)
                        .underline()
                }
                .padding(.horizontal, 40)
                Spacer()
                
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

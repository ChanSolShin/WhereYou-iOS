//
//  LoginView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import NMapsMap

struct LoginView: View {
    
    @EnvironmentObject var viewModel: LoginViewModel  // 전역 LoginViewModel 사용 (초기화하지 않음)
    @State private var showPassword = false
    @State private var showAlert = false  // 로그인 실패 Alert용
    
    var body: some View {
        NavigationView {
            VStack {
                // 앱 로고 표시
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 100)
                    .padding(.top, 60)
                    .padding(.bottom, 10)
                
                Text("로그인")
                    .font(.title2)
                    .padding(.bottom, 50)
                    .fontWeight(.bold)
                
                // 이메일 입력
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
                
                // 비밀번호 입력
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    
                    if showPassword {
                        TextField("비밀번호를 입력하세요", text: $viewModel.user.password)
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
                .padding(.top, 10)
                
                NavigationLink(destination: FindPasswordView()){
                    Text("비밀번호 찾기")
                }
                .font(.system(size: 14))
                .padding(.leading, 250)
                .foregroundColor(.gray)
                .underline()
                .padding(.horizontal, 10)
                .padding(.bottom, 15)
                
                // 로그인 및 회원가입 버튼
                NavigationLink(destination: MainTabView(), isActive: $viewModel.isLoggedIn) {
                    Button(action: {
                        viewModel.login()
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
                .padding(.bottom, 20)
                
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
                    
                    NavigationLink(destination: FindEmailView()){
                        Text("이메일 찾기")
                            .foregroundColor(.black)
                            .underline()
                    }
                }
                .padding(.horizontal, 40)
                Spacer()
            }
            .onAppear {
                let loggedInStatus = UserDefaults.standard.bool(forKey: "isLoggedIn")
                print(loggedInStatus)
            }
            .alert(isPresented: Binding<Bool>(
                get: {
                    showAlert || viewModel.currentAlert != nil
                },
                set: { newValue in
                    if !newValue {
                        showAlert = false
                        viewModel.currentAlert = nil
                    }
                }
            )) {
                if showAlert {
                    return Alert(
                        title: Text("로그인 실패"),
                        message: Text("이메일 또는 비밀번호가 일치하지 않습니다."),
                        dismissButton: .default(Text("확인"))
                    )
                } else if let alertType = viewModel.currentAlert {
                    switch alertType {
                    case .forcedLogout:
                        return Alert(
                            title: Text("강제 로그아웃"),
                            message: Text("다른 기기에서 로그인되어 로그아웃되었습니다."),
                            dismissButton: .default(Text("확인"))
                        )
                    case .newDeviceLogin:
                        return Alert(
                            title: Text("다른 기기에서 로그인 중입니다."),
                            message: Text("강제 로그아웃하고, 현재 기기에서 로그인 하시겠습니까?"),
                            primaryButton: .destructive(Text("확인"), action: {
                                viewModel.confirmNewDeviceLogin()
                            }),
                            secondaryButton: .cancel(Text("취소"), action: {
                                viewModel.cancelNewDeviceLogin()
                            })
                        )
                    }
                } else {
                    return Alert(title: Text(""), message: Text(""), dismissButton: .default(Text("확인")))
                }
            }
            .onChange(of: viewModel.loginErrorMessage) { errorMessage in
                if errorMessage != nil {
                    showAlert = true
                    viewModel.loginErrorMessage = nil
                }
            }
        }
    }
}

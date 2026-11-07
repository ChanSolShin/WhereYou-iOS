//
//  LoginView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI

struct LoginView: View {
    
    @EnvironmentObject var viewModel: LoginViewModel  // 전역 LoginViewModel 사용 (초기화하지 않음)
    @State private var showPassword = false
    
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
                .glassSurface(radius: 12)
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
                .glassSurface(radius: 12)
                .padding(.horizontal, 30)
                .padding(.bottom, 20)
                .padding(.top, 10)
                
                // 로그인 버튼 (중복 전환 방지를 위해 NavigationLink 제거)
                Button(action: {
                    viewModel.login()
                }) {
                    Group {
                        if viewModel.isLoggingIn {
                            ProgressView()
                                .tint(.white)
                                .accessibilityLabel("로그인 중")
                        } else {
                            Text("이메일로 로그인")
                        }
                    }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .cornerRadius(40)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 30)
                .disabled(viewModel.isLoggingIn)
                .padding(.bottom, 16)

                // 회원가입 | 이메일 찾기 | 비밀번호 찾기
                HStack(spacing: 12) {
                    NavigationLink(destination: SignUpView()) {
                        Text("회원가입")
                    }
                    Text("|")
                        .foregroundColor(.gray.opacity(0.5))
                    NavigationLink(destination: FindEmailView()) {
                        Text("이메일 찾기")
                    }
                    Text("|")
                        .foregroundColor(.gray.opacity(0.5))
                    NavigationLink(destination: FindPasswordView()) {
                        Text("비밀번호 찾기")
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.bottom, 28)

                // 소셜 로그인
                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                    Text("또는")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 1)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 16)

                // 원형 로고 버튼 (카카오/네이버 추가 시 SocialAuthProvider에 case 추가)
                HStack(spacing: 20) {
                    ForEach(SocialAuthProvider.allCases, id: \.self) { provider in
                        SocialLoginButton(provider: provider) {
                            viewModel.socialLogin(with: provider)
                        }
                    }
                }
                .disabled(viewModel.isLoggingIn)

                Spacer()
            }
            .background(GlassBackdrop())
            .alert(item: $viewModel.currentAlert) { alertType in
                switch alertType {
                    case .loginFailed(let message):
                        return Alert(
                            title: Text("로그인 실패"),
                            message: Text(message),
                            dismissButton: .default(Text("확인"))
                        )
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
            }
        }
    }
}

//
//  ProfileView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @State private var isLoggedIn = true // 로그인 상태 관리
    @State private var showLogoutAlert = false // 로그아웃 알림 상태
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                if let profile = viewModel.profile {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(profile.email)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        NavigationLink(destination: EditProfileView(viewModel: viewModel), isActive: $viewModel.isEditing) {
                            Button(action: {
                                viewModel.isEditing = true
                            }) {
                                Text("내 정보 수정")
                                    .font(.footnote)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.2)))
                    .padding(.horizontal)
                    .padding(.bottom, 15)
                    .padding(.top, 25)
                }
                
                Divider()
                
                // 서비스 정보
                VStack(alignment: .leading, spacing: 20) {
                    Text("서비스 정보")
                        .font(.title3)
                        .padding(.top,10)
                        .bold()
                    HStack {
                        Image(systemName: "person")
                            .font(.title2)
                        Text("개인정보 처리방침")
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    
                    
                    NavigationLink(destination: ReportView()) {
                        HStack {
                            Image(systemName: "message")
                                .font(.title2)
                            Text("오류신고")
                                .font(.body)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.vertical, 8)
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.title2)
                        Text("버전 정보")
                            .font(.body)
                        Spacer()
                        Text("1.0.0v")
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    
                    // 로그아웃 버튼
                    HStack {
                        Spacer()
                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            Text("로그아웃")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("설정")
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }
            .onAppear {
                viewModel.fetchUserProfile()
            }
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("로그아웃 하시겠습니까?"),
                    primaryButton: .destructive(Text("로그아웃"), action: {
                        viewModel.logout()
                        isLoggedIn = false // 로그아웃 시 로그인 상태 변경
                    }),
                    secondaryButton: .cancel(Text("취소"))
                )
            }
            .fullScreenCover(isPresented: Binding(
                get: { !isLoggedIn },
                set: { _ in }
            )) {
                LoginView() // 로그아웃 시 표시될 로그인 화면
            }
        }
    }
}

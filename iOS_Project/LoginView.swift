//
//  ContentView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""

    var body: some View {
        NavigationView {
            VStack {
                // 앱 이름 표시
                Text("MyApp") // 이곳에 앱 이름 적기
                    .font(.largeTitle)
                    .padding(.top, 70)
                    .padding(.bottom, 70)
                
                // 아이디 입력 필드
                HStack {
                    Image(systemName: "person") 
                        .foregroundColor(.gray)
                    TextField("이메일", text: $username)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 40)

                // 비밀번호 입력 필드
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                    SecureField("비밀번호", text: $password)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                
                // 로그인 및 회원가입 버튼
                HStack(spacing: 80) {
                    NavigationLink(destination: MeetingListView()) {
                        Text("로그인")
                            .foregroundColor(.blue)
                    }

                    NavigationLink(destination: CreateAccountView())  {
                        Text("회원가입")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer()             }
        }
    }
}

// 프리뷰용 코드
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}


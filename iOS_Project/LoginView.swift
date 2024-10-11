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
                Text("MyApp")
                    .font(.largeTitle)
                    .padding(.bottom, 40)
                
                // 아이디 입력 필드 (유저 이미지 포함)
                HStack {
                    Image(systemName: "person") // 유저 이미지
                        .foregroundColor(.gray)
                    TextField("아이디", text: $username)
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 40)

                // 비밀번호 입력 필드 (자물쇠 이미지 포함)
                HStack {
                    Image(systemName: "lock") // 자물쇠 이미지
                        .foregroundColor(.gray)
                    SecureField("비밀번호", text: $password)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                
                // 로그인 및 회원가입 버튼
                HStack(spacing: 30) { // 두 버튼 사이 간격을 30으로 설정
                    // 로그인 버튼: MeetingListView로 이동
                    NavigationLink(destination: MeetingListView()) {
                        Text("로그인")
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        // 회원가입 액션
                    }) {
                        Text("회원가입")
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 40)
                
                Spacer() // 화면 하단 여백
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


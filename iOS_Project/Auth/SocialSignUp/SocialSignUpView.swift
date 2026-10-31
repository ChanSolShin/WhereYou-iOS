//
//  SocialSignUpView.swift
//  iOS_Project
//
//  Created by 최용훈 on 31/10/26.
//

import SwiftUI

// 소셜 최초 로그인 후 회원정보 입력 화면
// TODO: 회원정보 입력 흐름 구현 (현재는 라우팅 연결용)
struct SocialSignUpView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 16) {
            Text("회원정보 입력이 필요합니다.")
                .font(.title3)
                .fontWeight(.bold)

            Button("처음으로") {
                loginViewModel.signOut(updateFirestore: false)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlassBackdrop())
    }
}

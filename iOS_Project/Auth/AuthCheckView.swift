//
//  AuthCheckView.swift
//  iOS_Project
//
//  Created by 최용훈 on 31/10/26.
//

import SwiftUI

// 앱 시작 시 사용자 정보 확인 중 / 확인 실패 화면
struct AuthCheckView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel

    var body: some View {
        VStack(spacing: 16) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 100)

            if loginViewModel.authState == .checkFailed {
                Text("사용자 정보를 불러오지 못했습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)

                Button(action: {
                    loginViewModel.retryAutoLoginCheck()
                }) {
                    Text("다시 시도")
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .cornerRadius(40)
                }
                .padding(.horizontal, 30)
            } else {
                ProgressView()
                    .accessibilityLabel("사용자 정보 확인 중")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(GlassBackdrop())
    }
}

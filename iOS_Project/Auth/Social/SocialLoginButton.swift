//
//  SocialLoginButton.swift
//  iOS_Project
//
//  Created by 최용훈 on 02/11/26.
//

import SwiftUI

// 소셜 로그인 원형 로고 버튼 (각 브랜드 가이드의 로고 전용 버튼 기준)
// TODO: 카카오/네이버 - 공식 원형 버튼 이미지 에셋 추가 후 case 추가
struct SocialLoginButton: View {
    let provider: SocialAuthProvider
    let action: () -> Void

    private let size: CGFloat = 60

    var body: some View {
        Button(action: action) {
            content
                .frame(width: size, height: size)
        }
        .contentShape(Circle())
        .accessibilityLabel("\(provider.displayName)로 로그인")
    }

    @ViewBuilder
    private var content: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.4, height: size * 0.4)
                .foregroundColor(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(Color.black))
        case .google:
            Image("GoogleLogo")
                .resizable()
                .scaledToFit()
        }
    }
}

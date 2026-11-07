//
//  SocialLoginButton.swift
//  iOS_Project
//
//  Created by 최용훈 on 02/11/26.
//

import SwiftUI

// 소셜 로그인 원형 로고 버튼 (각 브랜드 가이드의 로고 전용 버튼 기준)
struct SocialLoginButton: View {
    let provider: SocialAuthProvider
    let action: () -> Void

    private let size: CGFloat = 60

    var body: some View {
        Button(action: action) {
            SocialProviderLogo(provider: provider, size: size)
        }
        .contentShape(Circle())
        .accessibilityLabel("\(provider.displayName)로 로그인")
    }
}

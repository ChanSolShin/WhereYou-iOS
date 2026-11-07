//
//  SocialProviderLogo.swift
//  iOS_Project
//
//  Created by 최용훈 on 07/11/26.
//

import SwiftUI

// 소셜 로그인 수단 원형 로고 (로그인 버튼, 마이페이지 로그인 수단 배지 공통)
// TODO: 카카오/네이버 - 공식 원형 로고 에셋 추가 후 case 추가
struct SocialProviderLogo: View {
    let provider: SocialAuthProvider
    let size: CGFloat

    var body: some View {
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
                .frame(width: size, height: size)
        }
    }
}

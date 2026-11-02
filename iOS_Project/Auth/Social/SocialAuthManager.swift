//
//  SocialAuthManager.swift
//  iOS_Project
//
//  Created by 최용훈 on 02/11/26.
//

import FirebaseAuth

// 소셜 인증 결과로 Firebase 로그인 처리
// 추후 마이페이지 계정 연결(link), 탈퇴 재인증(reauthenticate)도 같은 인증 결과 재사용
enum SocialAuthManager {
    struct SignInResult {
        let user: FirebaseAuth.User
        let isNewUser: Bool
        let social: SocialAuthResult
    }

    static func service(for provider: SocialAuthProvider) -> SocialAuthService {
        switch provider {
        case .google: return GoogleAuthService()
        case .apple: return AppleAuthService()
        }
    }

    // 소셜 인증 → Firebase 로그인
    @MainActor
    static func signIn(with provider: SocialAuthProvider) async throws -> SignInResult {
        let social = try await service(for: provider).authorize()

        let authResult: AuthDataResult
        switch social.credential {
        case .firebase(let credential):
            authResult = try await Auth.auth().signIn(with: credential)
        }

        // Apple 이름은 최초 인증 시에만 제공되므로 바로 Auth displayName에 저장
        if let name = social.name, authResult.user.displayName?.isEmpty ?? true {
            let change = authResult.user.createProfileChangeRequest()
            change.displayName = name
            try? await change.commitChanges()
        }

        return SignInResult(
            user: authResult.user,
            isNewUser: authResult.additionalUserInfo?.isNewUser ?? false,
            social: social
        )
    }
}

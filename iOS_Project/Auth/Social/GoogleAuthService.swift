//
//  GoogleAuthService.swift
//  iOS_Project
//
//  Created by 최용훈 on 02/11/26.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

// Google 로그인 (클라이언트 ID는 AppDelegate에서 설정)
final class GoogleAuthService: SocialAuthService {
    let provider: SocialAuthProvider = .google

    @MainActor
    func authorize() async throws -> SocialAuthResult {
        guard let presenter = UIApplication.shared.topViewController else {
            throw SocialAuthError.noPresenter
        }

        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        } catch GIDSignInError.canceled {
            throw SocialAuthError.canceled
        }

        guard let idToken = result.user.idToken?.tokenString else {
            throw SocialAuthError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        return SocialAuthResult(
            provider: .google,
            credential: .firebase(credential),
            name: result.user.profile?.name,
            email: result.user.profile?.email,
            authorizationCode: nil
        )
    }

    // 로그아웃 시 Google 세션도 종료 (다음 로그인 때 계정 선택 화면 표시)
    static func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}

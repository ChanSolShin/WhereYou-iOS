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

    // 탈퇴 시 앱의 Google 계정 접근 권한 해제
    // 실패해도 탈퇴는 이미 완료된 상태라 로그만 남김
    @MainActor
    static func disconnect() async {
        do {
            if GIDSignIn.sharedInstance.currentUser == nil {
                _ = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            }
            try await GIDSignIn.sharedInstance.disconnect()
        } catch {
            print("[Auth] Google disconnect failed (code: \((error as NSError).code))")
        }
    }
}

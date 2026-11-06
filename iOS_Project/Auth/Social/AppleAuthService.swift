//
//  AppleAuthService.swift
//  iOS_Project
//
//  Created by 최용훈 on 02/11/26.
//

import UIKit
import AuthenticationServices
import CryptoKit
import FirebaseAuth

// Apple 로그인
// nonce: 원본은 Firebase credential에, SHA256 해시는 Apple 요청에 전달
final class AppleAuthService: NSObject, SocialAuthService {
    let provider: SocialAuthProvider = .apple

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var controller: ASAuthorizationController?

    @MainActor
    func authorize() async throws -> SocialAuthResult {
        let nonce = Self.randomNonce()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        let appleCredential = try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
        controller = nil

        guard let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw SocialAuthError.missingToken
        }
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )
        return SocialAuthResult(
            provider: .apple,
            credential: .firebase(credential),
            name: Self.formattedName(appleCredential.fullName),
            email: appleCredential.email,
            authorizationCode: appleCredential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }

    // 탈퇴 시 Apple 토큰 해지 (App Store 심사 요구사항, 인증 코드는 발급 후 5분 유효)
    // 실패해도 탈퇴는 계속 진행
    static func revokeToken(authorizationCode: String?) async {
        guard let authorizationCode else {
            print("[Auth] Apple revoke skipped (no authorization code)")
            return
        }
        do {
            try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
        } catch {
            print("[Auth] Apple revoke failed (code: \((error as NSError).code))")
        }
    }

    private func finish(with result: Result<ASAuthorizationAppleIDCredential, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    // 최초 인증 시에만 이름 제공, 이후에는 nil
    private static func formattedName(_ components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
        return name.isEmpty ? nil : name
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        precondition(status == errSecSuccess, "nonce 생성 실패")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleAuthService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(with: .failure(SocialAuthError.missingToken))
            return
        }
        finish(with: .success(credential))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if (error as? ASAuthorizationError)?.code == .canceled {
            finish(with: .failure(SocialAuthError.canceled))
        } else {
            finish(with: .failure(error))
        }
    }
}

extension AppleAuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.topViewController?.view.window ?? ASPresentationAnchor()
    }
}

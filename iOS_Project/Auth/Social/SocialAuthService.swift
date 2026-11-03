//
//  SocialAuthService.swift
//  iOS_Project
//
//  Created by 최용훈 on 02/11/26.
//

import UIKit
import FirebaseAuth

// 소셜 로그인 수단
// TODO: 카카오/네이버 - case 추가 (Cloud Functions Custom Token 방식)
// case 순서 = 로그인 화면 버튼 순서 (Apple 가이드상 Apple 버튼을 다른 소셜 버튼보다 눈에 덜 띄게 두지 않도록 첫 번째)
enum SocialAuthProvider: CaseIterable {
    case apple
    case google

    // Firebase Auth providerID (users 문서 providers 값과 동일)
    var providerID: String {
        switch self {
        case .google: return "google.com"
        case .apple: return "apple.com"
        }
    }

    // 안내 문구용 이름
    var displayName: String {
        switch self {
        case .google: return "Google"
        case .apple: return "Apple"
        }
    }
}

// 소셜 인증 후 Firebase 로그인에 사용할 자격 증명
enum SocialCredential {
    case firebase(AuthCredential)  // Google, Apple
    // TODO: 카카오/네이버 - case customToken(String) 추가 (Functions에서 토큰 검증 후 발급)
}

// 소셜 인증 결과
struct SocialAuthResult {
    let provider: SocialAuthProvider
    let credential: SocialCredential
    let name: String?               // 회원정보 입력 미리 채우기용 (Apple은 최초 인증 시에만 제공)
    let email: String?              // 회원정보 입력 미리 채우기용 (Apple은 최초 인증 시에만 제공)
    let authorizationCode: String?  // Apple 토큰 해지용 (탈퇴 시 사용, 5분 유효)
}

enum SocialAuthError: LocalizedError {
    case canceled       // 사용자가 로그인 창을 닫음 (알림 없이 무시)
    case noPresenter
    case missingToken

    var errorDescription: String? {
        switch self {
        case .canceled: return "로그인이 취소되었습니다."
        case .noPresenter: return "로그인 화면을 표시할 수 없습니다. 다시 시도해주세요."
        case .missingToken: return "로그인 정보를 확인하지 못했습니다. 다시 시도해주세요."
        }
    }
}

// 소셜 SDK 인증만 담당 (Firebase 로그인/연결/재인증은 SocialAuthManager에서 처리)
protocol SocialAuthService {
    var provider: SocialAuthProvider { get }
    @MainActor func authorize() async throws -> SocialAuthResult
}

extension UIApplication {
    // 소셜 로그인 창을 띄울 최상단 화면
    var topViewController: UIViewController? {
        let keyWindow = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        var top = keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

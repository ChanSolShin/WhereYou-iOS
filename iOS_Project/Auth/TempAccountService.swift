//
//  TempAccountService.swift
//  iOS_Project
//
//  Created by 최용훈 on 05/11/26.
//

import FirebaseAuth
import FirebaseFunctions

// 가입 미완료 임시 계정 삭제 요청 (서버 discardTempAccount)
// 앱의 계정 삭제는 로그인 후 약 5분이 지나면 거부되므로 서버(Admin SDK)에서 삭제
// 일시적인 오류(서버 시작 지연, 네트워크 끊김)는 1회 재시도
// 그래도 실패하면 호출한 쪽은 로그아웃 진행, 서버 정리 작업(deleteUnlinkedTempAccounts)이 나중에 삭제
enum TempAccountService {
    private static let maxRetryCount = 1

    static func discard(completion: @escaping () -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion()
            return
        }
        requestDiscard(retryCount: 0, completion: completion)
    }

    private static func requestDiscard(retryCount: Int, completion: @escaping () -> Void) {
        let callable = Functions.functions().httpsCallable("discardTempAccount")
        callable.timeoutInterval = 10
        callable.call { _, error in
            if let error = error {
                print("[TempAccount] Discard failed (code: \((error as NSError).code), retry: \(retryCount))")
                if retryCount < maxRetryCount, isRetryable(error) {
                    requestDiscard(retryCount: retryCount + 1, completion: completion)
                    return
                }
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }

    // 가입 완료 계정(failed-precondition), 로그인 정보 없음(unauthenticated) 등은 다시 시도해도 같은 결과
    private static func isRetryable(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return true  // 네트워크 오류 등
        }
        switch code {
        case .failedPrecondition, .unauthenticated, .permissionDenied, .invalidArgument, .notFound:
            return false
        default:
            return true
        }
    }
}

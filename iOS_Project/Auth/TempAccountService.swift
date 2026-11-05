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
// 실패해도 호출한 쪽은 로그아웃 진행, 서버 정리 작업(deleteUnlinkedTempAccounts)이 나중에 삭제
enum TempAccountService {
    static func discard(completion: @escaping () -> Void) {
        guard Auth.auth().currentUser != nil else {
            completion()
            return
        }
        let callable = Functions.functions().httpsCallable("discardTempAccount")
        callable.timeoutInterval = 10
        callable.call { _, error in
            if let error = error {
                print("[TempAccount] Discard failed (code: \((error as NSError).code))")
            }
            DispatchQueue.main.async {
                completion()
            }
        }
    }
}

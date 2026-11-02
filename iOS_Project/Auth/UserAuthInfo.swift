//
//  UserAuthInfo.swift
//  iOS_Project
//
//  Created by 최용훈 on 31/10/26.
//

import FirebaseAuth
import FirebaseFirestore

// users 문서의 로그인 수단 정보 (providers, loginEmail)
// providers: 연결된 로그인 수단 (표시용, 실제 권한은 Firebase Auth 기준)
// loginEmail: 비밀번호 로그인 이메일 (비밀번호 계정만, 이메일 찾기용)
enum UserAuthInfo {
    // Firebase Auth가 관리하는 로그인 수단
    // 그 외 값(카카오/네이버 등 서버 관리 값)은 동기화 시 유지
    private static let firebaseProviderIDs: Set<String> = ["password", "phone", "google.com", "apple.com"]

    // 현재 Auth 기준 providers, loginEmail 값
    static func fields(for user: FirebaseAuth.User, existing data: [String: Any]? = nil) -> [String: Any] {
        let authProviders = Set(user.providerData.map(\.providerID)).intersection(firebaseProviderIDs)
        let serverProviders = Set(data?["providers"] as? [String] ?? []).subtracting(firebaseProviderIDs)
        var fields: [String: Any] = ["providers": authProviders.union(serverProviders).sorted()]
        if let loginEmail = user.providerData.first(where: { $0.providerID == "password" })?.email {
            fields["loginEmail"] = loginEmail
        }
        return fields
    }

    // 기존 유저 backfill 및 로그인 수단 변경 반영 (값이 다를 때만 저장)
    // 실패해도 로그인 흐름은 막지 않음
    static func syncIfNeeded(user: FirebaseAuth.User, existing data: [String: Any]) {
        var update = fields(for: user, existing: data)
        let providersChanged = data["providers"] as? [String] != update["providers"] as? [String]
        let loginEmailChanged = data["loginEmail"] as? String != update["loginEmail"] as? String
        guard providersChanged || loginEmailChanged else { return }

        if update["loginEmail"] == nil {
            update["loginEmail"] = FieldValue.delete()
        }
        Firestore.firestore().collection("users").document(user.uid).setData(update, merge: true) { error in
            if let error = error {
                print("[Auth] Login provider sync failed (code: \((error as NSError).code))")
            }
        }
    }
}

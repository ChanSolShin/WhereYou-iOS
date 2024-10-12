//
//  iOS_ProjectApp.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI

// 로그인 상태를 확인하고, 로그인이 된 상태라면 MeetingView로 시작, 안되어있으면 LoginView로 시작하게 설정
@main

struct iOS_ProjectApp: App {
    @StateObject private var loginViewModel = LoginViewModel()
    var body: some Scene {
        WindowGroup {
            LoginView()
            if loginViewModel.isLoggedIn {
                          MainTabView() // 로그인된 경우 탭 뷰로 이동
                      }
        }
    }
}


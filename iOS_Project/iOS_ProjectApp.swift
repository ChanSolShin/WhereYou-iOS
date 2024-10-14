//
//  iOS_ProjectApp.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Firebase

// 로그인 상태를 확인하고, 로그인이 된 상태라면 MeetingView로 시작, 안되어있으면 LoginView로 시작하게 설정
@main

struct iOS_ProjectApp: App {
    @StateObject private var loginViewModel = LoginViewModel()
    
    init(){
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            LoginView()
            if loginViewModel.isLoggedIn {
                          MainTabView() // 로그인된 경우 탭 뷰로 이동
            }else{
                LoginView() //로그인 되지 않을 경우 로그인 뷰로 이동
            }
        }
    }
}


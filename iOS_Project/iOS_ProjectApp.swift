//
//  iOS_ProjectApp.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Firebase
import CoreLocation
import NMapsMap
import UserNotifications

@main
struct iOS_ProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @ObservedObject private var locationCoordinator = AppLocationCoordinator.shared
    @StateObject private var loginViewModel = LoginViewModel()
    @State private var showAlert = false
    @State private var showNotificationAlert = false // 알림 권한 요청 상태
    
    var body: some Scene {
        WindowGroup {
            Group {
                    if loginViewModel.isLoggedIn {
                        MainTabView()
                            .onAppear {
                                locationCoordinator.startUpdatingLocation()
                                // 로그인 후 강제 로그아웃 리스너는 LoginViewModel에서 처리됨.
                            }
                    } else {
                        LoginView()
                    }
                }
            .environmentObject(loginViewModel) // LoginViewModel을 전역에서 사용
            .onAppear {
                // 위치 권한이 허용되지 않으면 경고 표시
                if locationCoordinator.authorizationStatus != .authorizedAlways {
                    showAlert = true
                }
                // 알림 권한 요청
                requestNotificationPermission()
            }
            .onChange(of: locationCoordinator.authorizationStatus) { status in
                if status == .denied || status == .restricted {
                    showAlert = true
                }
            }
        }
    }
    
    private func exitApp() {
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("알림 권한이 허용되었습니다.")
            } else {
                print("알림 권한이 거부되었습니다.")
                DispatchQueue.main.async {
                    self.showNotificationAlert = true
                }
            }
        }
    }
}

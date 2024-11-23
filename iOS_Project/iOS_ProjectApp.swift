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
    @ObservedObject private var locationCoordinator = AppLocationCoordinator.shared
    @StateObject private var loginViewModel = LoginViewModel()
    @State private var showAlert = false
    @State private var showNotificationAlert = false // 알림 권한 요청 상태
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if locationCoordinator.authorizationStatus == .authorizedAlways {
                    if loginViewModel.isLoggedIn {
                        MainTabView()
                            .onAppear {
                                locationCoordinator.startUpdatingLocation()
                            }

                    } else {
                        LoginView()
                    }
                } else if locationCoordinator.authorizationStatus == .notDetermined {
                    Text("위치 권한 요청 중...")
                        .onAppear {
                            // 권한 요청이 시작되었음을 나타내는 UI
                        }
                } else {
                    PermissionRequiredView() // 설정으로 이동하는 화면
                }
            }
            .onChange(of: locationCoordinator.authorizationStatus) { status in
                if status == .denied || status == .restricted {
                    showAlert = true
                }
            .onAppear {
                // 위치 권한이 허용되지 않으면 경고 표시
                if locationCoordinator.authorizationStatus != .authorizedAlways {
                    showAlert = true
                }
                
                // 앱이 실행될 때 알림 권한 요청
                requestNotificationPermission()
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("위치 권한이 필요합니다"),
                    message: Text("앱이 정상적으로 작동하려면 위치 권한을 항상 허용으로 설정해야 합니다."),
                    primaryButton: .default(Text("설정으로 이동")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("취소")) {

                        exitApp() // 취소 버튼 클릭 시, 앱 종료
                    }
                )
            }
            .alert(isPresented: $showNotificationAlert) {
                Alert(
                    title: Text("알림 권한이 필요합니다"),
                    message: Text("앱에서 알림을 받으려면 권한이 필요합니다."),
                    primaryButton: .default(Text("허용")) {
                        requestNotificationPermission()
                    },
                    secondaryButton: .cancel(Text("취소"))
                )
            }
        }
    }
    
    private func exitApp() {
        UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            exit(0)
        }
    }
    
    // 알림 권한 요청 함수
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("알림 권한이 허용되었습니다.")
            } else {
                print("알림 권한이 거부되었습니다.")
                DispatchQueue.main.async {
                    self.showNotificationAlert = true // 권한 거부 시 알림 권한 요청 메시지 표시
                }
            }
        }
    }
}

//
//  iOS_ProjectApp.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import CoreLocation
import NMapsMap
import UserNotifications
import FirebaseRemoteConfig

@main
struct iOS_ProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @ObservedObject private var locationCoordinator = AppLocationCoordinator.shared
    @StateObject private var loginViewModel = LoginViewModel()
    @State private var showAlert = false
    @State private var showNotificationAlert = false // 알림 권한 요청 상태
    @State private var showUpdateAlert = false
    
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
                // 앱이 포그라운드로 진입할 때 토큰 갱신
                NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
                    if let user = FirebaseAuth.Auth.auth().currentUser {
                        user.getIDTokenForcingRefresh(true) { token, error in
                            if let error = error {
                                print("🔥 토큰 갱신 실패: \(error.localizedDescription)")
                            } else {
                                print("✅ 토큰 갱신 성공")
                            }
                        }
                    }
                }
                let remoteConfig = RemoteConfig.remoteConfig()
                let settings = RemoteConfigSettings()
                settings.minimumFetchInterval = 0
                remoteConfig.configSettings = settings
                remoteConfig.fetchAndActivate { status, error in
                    let minVersion = remoteConfig["min_required_version"].stringValue ?? ""
                    if let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                        print("✅ minVersion: \(minVersion), currentVersion: \(currentVersion)")
                        
                        if isUpdateRequired(minVersion: minVersion, currentVersion: currentVersion) {
                            DispatchQueue.main.async {
                                showUpdateAlert = true // 현재버전, 파이어베이스에 등록된 최소버전과 비교해서 앱 업데이트 유도
                            }
                        }
                    }
                }
            }
            .onChange(of: locationCoordinator.authorizationStatus) { status in
                if status == .denied || status == .restricted {
                    showAlert = true
                }
            }
            .alert(isPresented: $showUpdateAlert) {
                Alert(
                    title: Text("업데이트 필요"),
                    message: Text("새로운 버전으로 업데이트가 필요합니다."),
                    dismissButton: .default(Text("업데이트")) {
                        if let url = URL(string: "itms-apps://itunes.apple.com/app/id6745590209") {
                            UIApplication.shared.open(url)
                        }
                    }
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
    
    private func isUpdateRequired(minVersion: String, currentVersion: String) -> Bool {
        let minComponents = minVersion.split(separator: ".").compactMap { Int($0) }
        let currentComponents = currentVersion.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(minComponents.count, currentComponents.count)

        for i in 0..<maxCount {
            let minPart = i < minComponents.count ? minComponents[i] : 0
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0

            if minPart > currentPart {
                return true
            } else if minPart < currentPart {
                return false
            }
        }
        return false
    }
}

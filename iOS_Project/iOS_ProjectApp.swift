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

// 로그인 상태를 확인하고, 로그인이 된 상태라면 MeetingView로 시작, 안되어있으면 LoginView로 시작하게 설정
@main
struct iOS_ProjectApp: App {
    @StateObject private var locationCoordinator = AppLocationCoordinator()
    @StateObject private var loginViewModel = LoginViewModel()
    @State private var showAlert = false

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
                } else {
                    Text("위치 권한을 항상 허용으로 설정해 주세요.")
                }
            }
            .onChange(of: locationCoordinator.authorizationStatus) { status in
                if status != .authorizedAlways {
                    showAlert = true
                }
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
                        exitApp()
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
}

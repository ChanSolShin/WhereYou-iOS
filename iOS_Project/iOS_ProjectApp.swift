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
    @StateObject private var loginViewModel = LoginViewModel()
    private let coordinator = LocationCoordinator()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                LoginView()
                    .onAppear{
                        coordinator.checkIfLocationServiceIsEnabled() // 앱 실행 시 위치 서비스 확인
                    }
                if loginViewModel.isLoggedIn {
                    MainTabView() // 로그인된 경우 탭 뷰로 이동
                }
            }
    
        }
    }
}

class LocationCoordinator: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func checkIfLocationServiceIsEnabled() {
        if CLLocationManager.locationServicesEnabled() {
            locationManager.requestWhenInUseAuthorization() // 위치 권한 요청
        } else {
            // 위치 서비스가 비활성화된 경우 사용자에게 알림 후 앱 종료
            showAlertAndExit()
        }
    }
    
    private func showAlertAndExit() {
        // 경고 창을 표시하고 앱을 종료하는 함수
        DispatchQueue.main.async {
            // UIAlertController를 사용하여 경고창 표시
            let alert = UIAlertController(title: "위치 서비스 비활성화",
                                          message: "위치 서비스가 비활성화되어 있습니다. 앱을 종료합니다.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                exit(0) // 위치서비스를 허용하지 않으면, 앱 종료
            })

            // 현재 최상위 뷰 컨트롤러에 경고창을 표시
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true, completion: nil)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            print("위치 권한이 허용되었습니다.")
        case .denied:
            print("위치 권한이 거부되었습니다.")
        case .restricted:
            print("위치 권한이 제한되었습니다.")
        case .notDetermined:
            print("위치 권한이 아직 결정되지 않았습니다.")
        default:
            break
        }
    }
}

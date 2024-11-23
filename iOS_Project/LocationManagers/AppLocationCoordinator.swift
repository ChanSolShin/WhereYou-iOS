import CoreLocation
import SwiftUI

class AppLocationCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AppLocationCoordinator()
    
    private let locationManager = CLLocationManager()
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    var currentLocation: CLLocationCoordinate2D?
    
    private override init() {
        super.init()
        locationManager.delegate = self
        checkAuthorizationStatus()
    }
    
    func checkAuthorizationStatus() {
        let currentStatus = locationManager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = currentStatus
        }
        print("Initial authorization status: \(currentStatus.rawValue)")
        
        if currentStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization() // 앱 사용 중 권한 요청
        } else if currentStatus == .authorizedWhenInUse {
            locationManager.requestAlwaysAuthorization() // 항상 허용 요청
        }
    }
    
    func startUpdatingLocation() {
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true // 백그라운드 위치 업데이트 활성화
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    private func showAlertForDisabledLocationService() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "위치 서비스 비활성화",
                message: "위치 서비스가 꺼져 있습니다. 설정에서 활성화해 주세요.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "확인", style: .default) { _ in
                exit(0)
            })
            
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async {
            self.authorizationStatus = status
            print("Updated authorization status: \(status.rawValue)")
        }
        
        switch status {
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization() // "항상 허용" 요청
        case .authorizedAlways:
            startUpdatingLocation() // 위치 업데이트 시작
        case .denied, .restricted:
            print("Location access denied or restricted.")
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latestLocation = locations.last else { return }
        currentLocation = latestLocation.coordinate
        print("Updated location: \(latestLocation.coordinate)")
    }
}

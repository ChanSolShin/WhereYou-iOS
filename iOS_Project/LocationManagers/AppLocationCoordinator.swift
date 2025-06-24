import CoreLocation
import FirebaseCore
import SwiftUI
import FirebaseDatabase
import FirebaseFirestore
import FirebaseAuth

class AppLocationCoordinator: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = AppLocationCoordinator()
    
    private let locationManager = CLLocationManager()
    private var locationUpdateTimer: DispatchSourceTimer? // Timer 추가
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocationCoordinate2D?
    
    // 활성화된 모임 정보
    @Published var activeMeetings: [MeetingModel] = []
    
    //lazy var: Firebase가 설정된 후에 데이터베이스를 참조하도록 설정
    private lazy var realtimeDB: DatabaseReference = {
        guard FirebaseApp.app() != nil else {
            fatalError("Wait for FirebaseApp to configured")
        }
        return Database.database().reference()
    }()
    
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
        guard locationUpdateTimer == nil else { return }
        
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.startUpdatingLocation()
        
        locationUpdateTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        locationUpdateTimer?.schedule(deadline: .now(), repeating: 5) // 5초마다 실행
        locationUpdateTimer?.setEventHandler { [weak self] in
            self?.uploadLocation()
        }
        locationUpdateTimer?.resume() // 타이머 실행
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationUpdateTimer?.cancel()
        locationUpdateTimer = nil
    }
    
    private func uploadLocation() {
        guard let currentLocation = currentLocation else {
            print("위치를 가져올 수 없습니다.")
            return
        }
        
        guard !activeMeetings.isEmpty else {
            return
        }
        
        let latitude = currentLocation.latitude
        let longitude = currentLocation.longitude
        print("현재 위치 업로드: (\(latitude), \(longitude))")
        
        // 활성화된 모든 모임에 대해 위치 업로드
        for meeting in activeMeetings {
            realtimeDB.child("meetings").child(meeting.id).child("locations").child(getCurrentUserID()).setValue([
                "latitude": latitude,
                "longitude": longitude,
                "timestamp": ServerValue.timestamp()
            ]) { error, _ in
                if let error = error {
                    print("Failed to update location for meeting \(meeting.id): \(error.localizedDescription)")
                } else {
                    print("Location updated successfully for meeting \(meeting.id)")
                }
            }
        }
    }
    
    // 현재 사용자 ID 가져오기
    private func getCurrentUserID() -> String {
        return Auth.auth().currentUser?.uid ?? "unknown_user"
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
    
    // 모임 등록
    func registerMeeting(_ meeting: MeetingModel) {
        let currentUID = getCurrentUserID()
        let db = Firestore.firestore()
        
        db.collection("meetings").document(meeting.id).getDocument { [weak self] document, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Firestore에서 모임 문서 조회 실패: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists,
                  let firestoreMembers = document.data()?["meetingMembers"] as? [String] else {
                print("모임 문서가 존재하지 않거나 멤버 정보가 없음")
                return
            }
            
            guard firestoreMembers.contains(currentUID) else {
                print("Firestore 기준 현재 사용자가 모임 멤버가 아님. 위치 업로드 차단.")
                return
            }
            
            // 리스너를 통해 모임 삭제 감지
            db.collection("meetings").document(meeting.id).addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Firestore 모임 삭제 감지 리스너 에러: \(error)")
                    return
                }
                
                if documentSnapshot == nil || !documentSnapshot!.exists {
                    self.activeMeetings.removeAll { $0.id == meeting.id }
                    print("모임이 Firestore에서 삭제됨. \(meeting.id)")
                    
                    if self.activeMeetings.isEmpty {
                        self.stopUpdatingLocation()
                    }
                }
            }
            
            let meetingDate = meeting.date
            let startUploadDate = Calendar.current.date(byAdding: .hour, value: -3, to: meetingDate)!
            let endUploadDate = Calendar.current.date(byAdding: .hour, value: 1, to: meetingDate)!
            let currentTime = Date()
            
            if currentTime >= startUploadDate && currentTime <= endUploadDate {
                self.activeMeetings.append(meeting)
                print("업로드 활성화된 모임 추가: \(meeting.id)")
                if self.authorizationStatus == .authorizedAlways {
                    self.startUpdatingLocation()
                }
            } else if currentTime < startUploadDate {
                // 업로드 시작 시점에 타이머 설정
                let delay = startUploadDate.timeIntervalSince(currentTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.activeMeetings.append(meeting)
                    print("타이머 후 업로드 활성화된 모임 추가: \(meeting.id)")
                    if self.authorizationStatus == .authorizedAlways {
                        self.startUpdatingLocation()
                    }
                }
            }
            
            // 업로드 종료 시점에 타이머 설정
            let endDelay = endUploadDate.timeIntervalSince(currentTime)
            if endDelay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + endDelay) {
                    self.activeMeetings.removeAll { $0.id == meeting.id }
                    print("업로드 비활성화된 모임 제거: \(meeting.id)")
                    
                    // 더 이상 활성화된 모임이 없으면 위치 업데이트 중지
                    if self.activeMeetings.isEmpty {
                        self.stopUpdatingLocation()
                    }
                }
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
        
    }
}

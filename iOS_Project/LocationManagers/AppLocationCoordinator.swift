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
    // 멤버십이 유효한 모임만 업로드 허용 (강퇴 즉시 차단을 위한 가드)
    private var memberAllowedMeetingIDs = Set<String>()
    
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
        
        // Foreground 진입 시 만료 모임 재검증
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(appWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
    }
    
    @objc private func appWillEnterForeground() {
        sweepActiveMeetings()
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
            DispatchQueue.main.async {
                self?.uploadLocation()
            }
        }
        locationUpdateTimer?.resume() // 타이머 실행
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        locationUpdateTimer?.cancel()
        locationUpdateTimer = nil
    }
    
    // 조회 가능 시간 유효성 검사
    private func isMeetingActive(_ meeting: MeetingModel, at date: Date = Date()) -> Bool {
        let start = Calendar.current.date(byAdding: .hour, value: -3, to: meeting.date) ?? meeting.date
        let end   = Calendar.current.date(byAdding: .hour, value:  1, to: meeting.date) ?? meeting.date
        return date >= start && date <= end
    }
    
    // 현재 시간 기준으로 활성 모임만 남기고, 없으면 업로드 중단
    private func sweepActiveMeetings(now: Date = Date()) {
        guard !activeMeetings.isEmpty else { return }
        DispatchQueue.main.async {
            let beforeCount = self.activeMeetings.count
            self.activeMeetings.removeAll { !self.isMeetingActive($0, at: now) }
            let afterCount = self.activeMeetings.count
            if beforeCount != afterCount {
                print("[Location] 만료된 모임 정리: before=\(beforeCount) → after=\(afterCount)")
            }
            if self.activeMeetings.isEmpty {
                print("[Location] 활성 모임 없음 → 위치 업데이트 중단")
                self.stopUpdatingLocation()
            }
        }
    }
    
    private func uploadLocation() {
        // 업로드 직전에 한 번 더 유효성 스윕
        sweepActiveMeetings()
        
        guard !activeMeetings.isEmpty else { return }
        guard let currentLocation = currentLocation else {
            print("위치를 가져올 수 없습니다.")
            return
        }
        
        let latitude = currentLocation.latitude
        let longitude = currentLocation.longitude
        
        // 멤버십이 유효(memberAllowedMeetingIDs)에 포함된 모임에만 업로드
        for meeting in activeMeetings where isMeetingActive(meeting) && memberAllowedMeetingIDs.contains(meeting.id) {
            print("현재 위치 업로드[\(meeting.id)]: (\(latitude), \(longitude))")
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
            
            // 허용 리스트 보강(초기 진입 시)
            self.memberAllowedMeetingIDs.insert(meeting.id)
            
            // 리스너를 통해 모임 삭제/멤버십 변경 감지
            db.collection("meetings").document(meeting.id).addSnapshotListener { [weak self] documentSnapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Firestore 모임 변경 리스너 에러: \(error)")
                    return
                }
                guard let snap = documentSnapshot else { return }
                
                if !snap.exists {
                    DispatchQueue.main.async {
                        self.memberAllowedMeetingIDs.remove(meeting.id)
                        self.activeMeetings.removeAll { $0.id == meeting.id }
                        print("모임이 Firestore에서 삭제됨. \(meeting.id)")
                        if self.activeMeetings.isEmpty { self.stopUpdatingLocation() }
                    }
                } else {
                    // 강퇴/멤버 제거 즉시 감지 -> 업로드 중단
                    if let data = snap.data(), let members = data["meetingMembers"] as? [String] {
                        if !members.contains(currentUID) {
                            DispatchQueue.main.async {
                                self.memberAllowedMeetingIDs.remove(meeting.id)
                                self.activeMeetings.removeAll { $0.id == meeting.id }
                                print("현재 사용자가 모임에서 제거됨 → 업로드 중단: \(meeting.id)")
                                if self.activeMeetings.isEmpty { self.stopUpdatingLocation() }
                            }
                            return
                        } else {
                            // 레이스 대비 보강
                            self.memberAllowedMeetingIDs.insert(meeting.id)
                        }
                    }
                    // meetingDate 변경 등 서버 상태 변동 재검증
                    self.sweepActiveMeetings()
                }
            }
            
            let meetingDate = meeting.date
            let startUploadDate = Calendar.current.date(byAdding: .hour, value: -3, to: meetingDate)!
            let endUploadDate = Calendar.current.date(byAdding: .hour, value: 1, to: meetingDate)!
            let currentTime = Date()
            
            if currentTime >= startUploadDate && currentTime <= endUploadDate {
                DispatchQueue.main.async {
                    self.activeMeetings.append(meeting)
                    // 즉시 시작 시 허용 리스트도 보강
                    self.memberAllowedMeetingIDs.insert(meeting.id)
                    print("업로드 활성화된 모임 추가: \(meeting.id)")
                    if self.authorizationStatus == .authorizedAlways {
                        self.startUpdatingLocation()
                    }
                }
            } else if currentTime < startUploadDate {
                // 업로드 시작 시점에 타이머 설정
                let delay = startUploadDate.timeIntervalSince(currentTime)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    DispatchQueue.main.async {
                        self.activeMeetings.append(meeting)
                        // 지연 시작 시 허용 리스트 보강
                        self.memberAllowedMeetingIDs.insert(meeting.id)
                        print("타이머 후 업로드 활성화된 모임 추가: \(meeting.id)")
                        if self.authorizationStatus == .authorizedAlways {
                            self.startUpdatingLocation()
                        }
                    }
                }
            }
            
            // 업로드 종료 시점에 타이머 설정
            let endDelay = endUploadDate.timeIntervalSince(currentTime)
            if endDelay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + endDelay) {
                    DispatchQueue.main.async {
                        // 종료 시 허용 리스트/대상 정리
                        self.memberAllowedMeetingIDs.remove(meeting.id)
                        self.activeMeetings.removeAll { $0.id == meeting.id }
                        print("업로드 비활성화된 모임 제거: \(meeting.id)")
                        if self.activeMeetings.isEmpty { self.stopUpdatingLocation() }
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
        DispatchQueue.main.async {
            self.currentLocation = latestLocation.coordinate
        }
    }
}

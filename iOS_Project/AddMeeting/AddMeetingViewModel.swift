//
//  AddMeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/17/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import CoreLocation

class AddMeetingViewModel: ObservableObject {
    @Published var meeting: AddMeetingModel = AddMeetingModel()
    
    init() {
        observeMeetingUpdates()
    }
    
    var successAddMeeting: Bool {
        return meeting.meetingName.isEmpty || meeting.meetingAddress == nil
    }
    
    func updateMeetingLocation(coordinate: CLLocationCoordinate2D, address: String) {
        meeting.meetingLocation = coordinate
        meeting.meetingAddress = address
    }
    
    func addCurrentUserToMeeting() {
        if let currentUserUID = Auth.auth().currentUser?.uid {
            meeting.meetingMaster.append(currentUserUID)
        } else {
            print("현재 로그인한 사용자의 UID를 가져올 수 없습니다.")
        }
    }
    
    func addMeeting() {
        let db = Firestore.firestore()
        
        let currentUserUID = Auth.auth().currentUser?.uid ?? ""
        meeting.meetingMaster.append(currentUserUID)
        meeting.meetingMembers.append(currentUserUID)
        
        let meetingData: [String: Any] = [
            "meetingName": meeting.meetingName,
            "meetingDate": Timestamp(date: meeting.meetingDate),
            "meetingAddress": meeting.meetingAddress ?? "",
            "meetingLocation": GeoPoint(latitude: meeting.meetingLocation.latitude, longitude: meeting.meetingLocation.longitude),
            "meetingMembers": meeting.meetingMembers,
            "meetingMaster": meeting.meetingMaster,
            "isLocationTrackingEnabled": false
        ]
        
        db.collection("meetings").addDocument(data: meetingData) { [weak self] error in
            if let error = error {
                print("모임을 추가하는 중 에러 발생: \(error)")
            } else {
                print("모임이 성공적으로 추가되었습니다.")
                self?.observeMeetingUpdates()
                self?.meeting = AddMeetingModel()
            }
        }
    }
    
    func observeMeetingUpdates() {
        let db = Firestore.firestore()
        print("Firestore 리스너 시작")
        
        db.collection("meetings").addSnapshotListener { [weak self] querySnapshot, error in
            if let error = error {
                print("Firestore 리스너 오류: \(error)")
                return
            }
            
            print("🔥 Firestore 데이터 변경 감지됨: \(querySnapshot?.documents.count ?? 0)개 문서")
            
            for document in querySnapshot?.documents ?? [] {
                let data = document.data()
                if let meetingDate = (data["meetingDate"] as? Timestamp)?.dateValue(),
                   let isTrackingEnabled = data["isLocationTrackingEnabled"] as? Bool {
                    
                    print("감지된 모임 시간: \(meetingDate), 위치 추적 상태: \(isTrackingEnabled)")
                    
                    self?.checkAndUpdateLocationTracking(
                        meetingDate: meetingDate,
                        isTrackingEnabled: isTrackingEnabled,
                        documentReference: document.reference
                    )
                } else {
                    print(" meetingDate 또는 isLocationTrackingEnabled 값이 올바르지 않음")
                }
            }
        }
    }
    
    func checkAndUpdateLocationTracking(meetingDate: Date, isTrackingEnabled: Bool, documentReference: DocumentReference) {
        let currentDate = Date()
        let timeDifference = meetingDate.timeIntervalSince(currentDate)
        
        if timeDifference <= 10800 && timeDifference > 0 {
            if !isTrackingEnabled {
                documentReference.updateData(["isLocationTrackingEnabled": true]) { error in
                    if let error = error {
                        print("isLocationTrackingEnabled 업데이트 오류: \(error)")
                    } else {
                        print("isLocationTrackingEnabled 값이 true로 업데이트됨")
                    }
                }
            }
        } else {
            if isTrackingEnabled {
                documentReference.updateData(["isLocationTrackingEnabled": false]) { error in
                    if let error = error {
                        print("isLocationTrackingEnabled 업데이트 오류: \(error)")
                    } else {
                        print("isLocationTrackingEnabled 값이 false로 업데이트됨")
                    }
                }
            }
        }
    }
    
    func fetchSearchResults(query: String, completion: @escaping ([SearchResult]) -> Void) {
        guard !query.isEmpty,
              let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://openapi.naver.com/v1/search/local.json?query=\(encodedQuery)&display=5&start=1&sort=random") else {
            completion([])
            return
        }

        guard let clientId = Bundle.main.infoDictionary?["NAVER_CLIENT_ID"] as? String,
              let clientSecret = Bundle.main.infoDictionary?["NAVER_CLIENT_SECRET"] as? String else {
            print("❌ 네이버 API 키가 Info.plist에서 누락되었습니다.")
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.setValue(clientId, forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue(clientSecret, forHTTPHeaderField: "X-Naver-Client-Secret")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(NaverLocalSearchResponse.self, from: data)
                    let results = decoded.items?.map {
                        SearchResult(
                            title: $0.title.htmlDecoded,
                            address: !$0.roadAddress.isEmpty ? $0.roadAddress : $0.address,
                            coordinate: self.convertTM128ToWGS84(
                                x: Double($0.mapx) ?? 0,
                                y: Double($0.mapy) ?? 0
                            )
                        )
                    } ?? []
                    completion(results)
                } catch {
                    print("디코딩 실패: \(error)")
                    completion([])
                }
            } else if let error = error {
                print("네트워크 오류: \(error.localizedDescription)")
                completion([])
            }
        }.resume()
    }
    
    func geocode(address: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        var cleanedAddress = address.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? address
        cleanedAddress = extractRoadAddress(from: cleanedAddress)
        print("📍 변환용 주소: \(cleanedAddress)")

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(cleanedAddress) { placemarks, error in
            if let error = error {
                print("주소 변환 실패: \(error.localizedDescription)")
                completion(nil)
                return
            }

            if let location = placemarks?.first?.location {
                completion(location.coordinate)
            } else {
                completion(nil)
            }
        }
    }

    func extractRoadAddress(from fullAddress: String) -> String {
        let units = ["층", "호", "동", "호점", "번지", "가", "지하", "상가", "점"]
        let tokens = fullAddress.components(separatedBy: " ")

        var result = [String]()
        for i in 0..<tokens.count {
            let token = tokens[i]

            if Int(token) != nil || token.contains("-") {
                result.append(token)
                if i + 1 < tokens.count {
                    let next = tokens[i + 1]
                    if units.contains(where: { next.contains($0) }) {
                        break
                    }
                }
            }
            else if let _ = Int(String(token.prefix { $0.isNumber })), units.contains(where: { token.contains($0) }) {
                break
            }
            else {
                result.append(token)
            }
        }

        return result.joined(separator: " ")
    }
    
    func convertTM128ToWGS84(x: Double, y: Double) -> CLLocationCoordinate2D {
        let lon = (x - 1000000.0) / 5.0 / 3600.0 + 127.5
        let lat = (y - 2000000.0) / 5.0 / 3600.0 + 38.0
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
}

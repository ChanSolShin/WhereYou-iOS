//
//  EditMeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import Foundation
import FirebaseFirestore
import CoreLocation

class EditMeetingViewModel: ObservableObject {
    @Published var meetingName: String = ""
    @Published var meetingDate: Date = Date()
    @Published var meetingLocation: GeoPoint = GeoPoint(latitude: 0, longitude: 0)
    @Published var meetingAddress: String = ""
    @Published var isLoading: Bool = true
    
    private let db = Firestore.firestore()
    
    func fetchMeetingData(meetingID: String) {
        isLoading = true
        db.collection("meetings").document(meetingID).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                print("Meeting data fetch error: \(error?.localizedDescription ?? "Unknown error")")
                self.isLoading = false
                return
            }
            self.meetingName = data["meetingName"] as? String ?? "이름 없음"
            self.meetingDate = (data["meetingDate"] as? Timestamp)?.dateValue() ?? Date()
            self.meetingLocation = data["meetingLocation"] as? GeoPoint ?? GeoPoint(latitude: 0, longitude: 0)
            self.meetingAddress = data["meetingAddress"] as? String ?? "주소 없음"
            self.isLoading = false
        }
    }
    
    func updateMeetingData(meetingID: String) {
        isLoading = true
        let updatedData: [String: Any] = [
            "meetingName": meetingName,
            "meetingDate": Timestamp(date: meetingDate),
            "meetingLocation": meetingLocation,
            "meetingAddress": meetingAddress
        ]
        
        db.collection("meetings").document(meetingID).updateData(updatedData) { error in
            if let error = error {
                print("Error updating meeting data: \(error.localizedDescription)")
                self.isLoading = false
            } else {
                print("Meeting data updated successfully")
                self.isLoading = false
            }
        }
    }
    
    func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let error = error {
                print("주소 변환 오류: \(error)")
                return
            }
            guard let placemark = placemarks?.first else {
                print("주소를 찾을 수 없습니다.")
                return
            }
            
            var addressComponents: [String] = []
            if let locality = placemark.locality { addressComponents.append(locality) }
            if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
            if let subThoroughfare = placemark.subThoroughfare { addressComponents.append(subThoroughfare) }
            
            self?.meetingAddress = addressComponents.joined(separator: " ")
            self?.meetingLocation = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }
    }
}

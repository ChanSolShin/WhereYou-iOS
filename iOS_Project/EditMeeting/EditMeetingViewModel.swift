//
//  EditMeetingViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import Foundation
import FirebaseFirestore

class EditMeetingViewModel: ObservableObject {
    @Published var meetingName: String = ""
    @Published var meetingDate: Date = Date()
    @Published var meetingLocation: GeoPoint = GeoPoint(latitude: 0, longitude: 0)
    @Published var meetingAddress: String = ""
    @Published var isLoading: Bool = true // 로딩 상태

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
 }



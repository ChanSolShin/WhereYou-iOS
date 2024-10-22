//
//  MeetingListViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import Foundation
import FirebaseFirestore
import Combine
import CoreLocation

class MeetingListViewModel: ObservableObject {
    @Published var meetings: [MeetingListModel] = []
    
    private var db = Firestore.firestore()
    
    init() {
        fetchMeetings()
    }
    
    func fetchMeetings() {
        db.collection("meetings").addSnapshotListener { (snapshot, error) in
            if let error = error {
                print("Error fetching meetings: \(error)")
            } else {
                if let snapshot = snapshot {
                    self.meetings = snapshot.documents.compactMap { document -> MeetingListModel? in
                        let data = document.data()
                        
                        // Firestore에서 meetingName, meetingDate, meetingAddress, meetingLocation 가져오기
                        guard let title = data["meetingName"] as? String,
                              let timestamp = data["meetingDate"] as? Timestamp,
                              let address = data["meetingAddress"] as? String,
                              let location = data["meetingLocation"] as? GeoPoint else {
                            return nil
                        }
                        
                        let date = timestamp.dateValue() // Firestore Timestamp를 Date로 변환
                        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                        
                        // MeetingListModel 초기화
                        return MeetingListModel(title: title, date: date, meetingAddress: address, meetingLocation: coordinate)
                    }
                    self.meetings.sort { $0.date < $1.date } // 날짜 기준으로 오름차순 정렬
                }
            }
        }
    }
    
    // Date 생성 함수는 그대로 유지
    static func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        return Calendar.current.date(from: dateComponents)
    }
}
var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월 d일 HH:mm"
    return formatter
}

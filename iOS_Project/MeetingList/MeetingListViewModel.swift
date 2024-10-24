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
    var meetingViewModel: MeetingViewModel // MeetingViewModel 인스턴스 추가
    
    init(meetingViewModel: MeetingViewModel) {
        self.meetingViewModel = meetingViewModel
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
                        guard let title = data["meetingName"] as? String,
                              let timestamp = data["meetingDate"] as? Timestamp,
                              let address = data["meetingAddress"] as? String,
                              let location = data["meetingLocation"] as? GeoPoint,
                              let memberIDs = data["meetingMembers"] as? [String],
                              let masterID = data["meetingMaster"] as? String else { 
                            return nil
                        }
                        
                        let date = timestamp.dateValue()
                        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                        
                        return MeetingListModel(title: title, date: date, meetingAddress: address, meetingLocation: coordinate, meetingMemberIDs: memberIDs, meetingMasterID: masterID)
                    }
                    self.meetings.sort { $0.date < $1.date }
                }
            }
        }
    }
    
    func selectMeeting(at index: Int) {
        guard index < meetings.count else { return }
        let meeting = meetings[index]
        
        // MeetingModel에 변환하여 MeetingViewModel에 전달
        let meetingModel = MeetingModel(title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation, meetingMemberIDs: meeting.meetingMemberIDs, meetingMasterID: meeting.meetingMasterID)
        meetingViewModel.selectMeeting(meeting: meetingModel)
    }
}

    
func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        return Calendar.current.date(from: dateComponents)
    }

var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월 d일 HH:mm"
    return formatter
}

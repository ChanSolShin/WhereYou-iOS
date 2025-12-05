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
import FirebaseAuth

class MeetingListViewModel: ObservableObject {
    @Published var meetings: [MeetingListModel] = []
    @Published var pendingRequestCount: Int = 0
    @Published var userProfile: ProfileModel? = nil
    
    private var db = Firestore.firestore()
    var meetingViewModel: MeetingViewModel // MeetingViewModel 인스턴스 추가
    private var currentUserUID: String? {
           Auth.auth().currentUser?.uid
       }
    
    init(meetingViewModel: MeetingViewModel = MeetingViewModel()) {
            self.meetingViewModel = meetingViewModel
            meetingViewModel.$pendingMeetingRequests
                .map { $0.count }
                .receive(on: DispatchQueue.main)
                .assign(to: &$pendingRequestCount)
            fetchMeetings()
            fetchCurrentUserProfile()
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
                              let masterID = data["meetingMaster"] as? String,
                             let isLocationTrackingEnabled = data["isLocationTrackingEnabled"]  else {
                            return nil
                        }

                        // 현재 사용자 UID 확인
                        guard let currentUserUID = self.currentUserUID else {
                            return nil
                        }
                        
                        // 현재 사용자가 meetingMembers에 포함되는지 확인
                        if !memberIDs.contains(currentUserUID) {
                            return nil
                        }
                        
                        let date = timestamp.dateValue()
                        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                        
                        return MeetingListModel(id: document.documentID, title: title, date: date, meetingAddress: address, meetingLocation: coordinate, meetingMemberIDs: memberIDs, meetingMasterID: masterID, isLocationTrackingEnabled: isLocationTrackingEnabled as! Bool)
                    }
                    self.meetings.sort { $0.date < $1.date }
                }
            }
        }
    }
      
    
    func selectMeeting(at index: Int) {
           guard index < meetings.count else { return }
           let meeting = meetings[index]
           
        let meetingModel = MeetingModel(id: meeting.id, title: meeting.title, date: meeting.date, meetingAddress: meeting.meetingAddress, meetingLocation: meeting.meetingLocation, meetingMemberIDs: meeting.meetingMemberIDs, meetingMasterID: meeting.meetingMasterID, isLocationTrackingEnabled: meeting.isLocationTrackingEnabled)
           meetingViewModel.selectMeeting(meeting: meetingModel)
       }
    
    func fetchCurrentUserProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        db.collection("users").document(uid).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                let name = data?["name"] as? String ?? "이름 없음"
                let email = data?["email"] as? String ?? ""
                let phoneNumber = data?["phoneNumber"] as? String
                let birthday = data?["birthday"] as? String
                DispatchQueue.main.async {
                    self.userProfile = ProfileModel(name: name, email: email, phoneNumber: phoneNumber, birthday: birthday)
                }
            } else {
                print("사용자 문서 없음 또는 오류: \(error?.localizedDescription ?? "")")
            }
        }
    }

    func isTodayUserBirthday() -> Bool {
        guard let birthday = userProfile?.birthday else { return false }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMdd"
        let todayString = formatter.string(from: Date())
        return birthday.suffix(4) == todayString
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

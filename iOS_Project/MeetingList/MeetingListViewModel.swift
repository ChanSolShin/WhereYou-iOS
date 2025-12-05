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
    @Published var searchText: String = ""
    @Published var isBirthdayBannerVisible: Bool = true
    @Published var meetingToOpenID: String? = nil
    
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

    var filteredMeetings: [MeetingListModel] {
        guard !searchText.isEmpty else { return meetings }
        return meetings.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var shouldShowBirthdayBanner: Bool {
        isBirthdayBannerVisible && isTodayUserBirthday()
    }

    var listDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    func dismissBirthdayBanner() {
        isBirthdayBannerVisible = false
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

    // MeetingView 딥링크
    func openMeeting(id: String) {
        // 로컬에 이미 있으면 즉시 네비게이션 이벤트 방출
        if meetings.first(where: { $0.id == id }) != nil {
            DispatchQueue.main.async { [weak self] in
                self?.meetingToOpenID = id
            }
            return
        }
        // 없으면 Firestore에서 가져온 뒤 추가하고 이벤트 방출
        fetchMeeting(by: id) { [weak self] model in
            guard let self = self, let model = model else { return }
            DispatchQueue.main.async {
                self.appendMeeting(model)
                self.meetingToOpenID = model.id
            }
        }
    }

    func appendMeeting(_ meeting: MeetingListModel) {
        guard !meetings.contains(where: { $0.id == meeting.id }) else { return }
        meetings.append(meeting)
        meetings.sort { $0.date < $1.date }
    }

    func fetchMeeting(by id: String, completion: @escaping (MeetingListModel?) -> Void) {
        db.collection("meetings").document(id).getDocument { snap, error in
            guard error == nil, let doc = snap, doc.exists, let data = doc.data() else {
                completion(nil)
                return
            }
            guard
                let title = data["meetingName"] as? String,
                let ts = data["meetingDate"] as? Timestamp,
                let address = data["meetingAddress"] as? String,
                let gp = data["meetingLocation"] as? GeoPoint,
                let members = data["meetingMembers"] as? [String],
                let master = data["meetingMaster"] as? String,
                let tracking = data["isLocationTrackingEnabled"] as? Bool
            else {
                completion(nil)
                return
            }
            let model = MeetingListModel(
                id: doc.documentID,
                title: title,
                date: ts.dateValue(),
                meetingAddress: address,
                meetingLocation: CLLocationCoordinate2D(latitude: gp.latitude, longitude: gp.longitude),
                meetingMemberIDs: members,
                meetingMasterID: master,
                isLocationTrackingEnabled: tracking
            )
            completion(model)
        }
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

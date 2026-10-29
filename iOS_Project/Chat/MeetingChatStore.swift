import Foundation
import Combine
import CoreLocation
import FirebaseAuth
import FirebaseFirestore

struct MeetingChatRoom: Identifiable {
    let meeting: MeetingListModel
    var id: String { meeting.id }
    var lastMessage: String?
    var lastMessageAt: Date?
    var incomingCount = 0
    var readCount = 0
    var unreadCount: Int { max(0, incomingCount - readCount) }
}

enum ChatCountLabel {
    static func text(_ count: Int) -> String { count > 999 ? "999+" : "\(count)" }
}

@MainActor
final class MeetingChatStore: ObservableObject {
    @Published private(set) var rooms: [MeetingChatRoom] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = true

    private var currentUID: String?
    private var meetingListener: ListenerRegistration?
    private var roomListeners: [String: [ListenerRegistration]] = [:]
    private let db = Firestore.firestore()

    var totalUnreadCount: Int {
        rooms.reduce(0) { $0 + $1.unreadCount }
    }

    func unreadCount(for meetingID: String) -> Int {
        rooms.first(where: { $0.id == meetingID })?.unreadCount ?? 0
    }

    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { stop(); return }
        guard currentUID != uid else { return }
        stop()
        currentUID = uid
        isLoading = true
        meetingListener = db.collection("meetings")
            .whereField("meetingMembers", arrayContains: uid)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self, self.currentUID == uid else { return }
                    if let error {
                        self.isLoading = false
                        self.errorMessage = "채팅방을 불러오지 못했습니다: \(error.localizedDescription)"
                        return
                    }
                    self.errorMessage = nil
                    self.isLoading = false
                    self.applyMeetings(snapshot?.documents ?? [], uid: uid)
                }
            }
    }

    func stop() {
        meetingListener?.remove()
        meetingListener = nil
        roomListeners.values.flatMap { $0 }.forEach { $0.remove() }
        roomListeners.removeAll()
        currentUID = nil
        rooms = []
        errorMessage = nil
        isLoading = false
    }

    private func applyMeetings(_ documents: [QueryDocumentSnapshot], uid: String) {
        let models = documents.compactMap { Self.decodeMeeting($0) }
        let activeIDs = Set(models.map(\.id))
        for id in Array(roomListeners.keys) where !activeIDs.contains(id) {
            roomListeners[id]?.forEach { $0.remove() }
            roomListeners.removeValue(forKey: id)
        }
        let previous = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })
        rooms = models.map { model in
            var room = previous[model.id] ?? MeetingChatRoom(meeting: model)
            room = MeetingChatRoom(
                meeting: model, lastMessage: room.lastMessage,
                lastMessageAt: room.lastMessageAt,
                incomingCount: room.incomingCount, readCount: room.readCount
            )
            return room
        }
        sortRooms()
        for model in models where roomListeners[model.id] == nil {
            let summary = db.collection("meetings").document(model.id)
                .collection("chat").document("summary")
                .addSnapshotListener { [weak self] document, _ in
                    DispatchQueue.main.async {
                        guard let self, self.currentUID == uid else { return }
                        self.updateRoom(model.id) { room in
                            let data = document?.data()
                            room.lastMessage = data?["lastMessagePreview"] as? String
                            room.lastMessageAt = (data?["lastMessageAt"] as? Timestamp)?.dateValue()
                            let counts = data?["incomingCounts"] as? [String: Int] ?? [:]
                            room.incomingCount = counts[uid] ?? 0
                        }
                    }
                }
            let read = db.collection("meetings").document(model.id)
                .collection("readStates").document(uid)
                .addSnapshotListener { [weak self] document, _ in
                    DispatchQueue.main.async {
                        guard let self, self.currentUID == uid else { return }
                        self.updateRoom(model.id) { room in
                            room.readCount = document?.data()?["lastReadIncomingCount"] as? Int ?? 0
                        }
                    }
                }
            roomListeners[model.id] = [summary, read]
        }
    }

    private func updateRoom(_ id: String, change: (inout MeetingChatRoom) -> Void) {
        guard let index = rooms.firstIndex(where: { $0.id == id }) else { return }
        change(&rooms[index])
        sortRooms()
    }

    private func sortRooms() {
        rooms.sort {
            ($0.lastMessageAt ?? $0.meeting.date) > ($1.lastMessageAt ?? $1.meeting.date)
        }
    }

    static func decodeMeeting(_ document: QueryDocumentSnapshot) -> MeetingListModel? {
        let data = document.data()
        guard let title = data["meetingName"] as? String,
              let date = data["meetingDate"] as? Timestamp,
              let address = data["meetingAddress"] as? String,
              let location = data["meetingLocation"] as? GeoPoint,
              let members = data["meetingMembers"] as? [String],
              let master = data["meetingMaster"] as? String else { return nil }
        return MeetingListModel(
            id: document.documentID, title: title, date: date.dateValue(),
            meetingAddress: address,
            meetingLocation: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            meetingMemberIDs: members, meetingMasterID: master,
            isLocationTrackingEnabled: data["isLocationTrackingEnabled"] as? Bool ?? false
        )
    }
}

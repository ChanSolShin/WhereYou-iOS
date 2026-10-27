import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

struct MeetingChatMessage: Identifiable, Equatable {
    let id: String
    let senderID: String
    let text: String
    let createdAt: Date?
    let sequence: Int
}

final class MeetingChatViewModel: ObservableObject {
    @Published private(set) var messages: [MeetingChatMessage] = []
    @Published private(set) var memberNames: [String: String] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var canChat = true
    @Published var errorMessage: String?
    @Published var draft = ""
    @Published private(set) var isSending = false
    @Published private(set) var isLoadingOlder = false
    @Published private(set) var hasOlderMessages = false

    let meetingID: String
    private let db = Firestore.firestore()
    private var messageListener: ListenerRegistration?
    private var meetingListener: ListenerRegistration?
    private var lastRequestedReadID: String?
    private var didRetryRead = false
    private var oldestDocument: QueryDocumentSnapshot?
    private var olderMessages: [MeetingChatMessage] = []
    private var pendingMessageID: String?
    private var pendingText: String?

    init(meetingID: String) {
        self.meetingID = meetingID
#if DEBUG
        if ChatKeyboardUITest.isEnabled {
            let count = ProcessInfo.processInfo.arguments.contains("--short-chat") ? 2 : 40
            messages = (1...count).map { index in
                MeetingChatMessage(id: index == count ? "fixture-last" : "fixture-\(index)",
                                   senderID: "fixture-member", text: "메시지 \(index)\n키보드를 열고 닫아도 마지막 줄이 보여야 합니다.",
                                   createdAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)), sequence: index)
            }
            memberNames = ["fixture-member": "테스트 멤버"]
            isLoading = false
        }
#endif
    }

    func start() {
        guard !ChatKeyboardUITest.isEnabled else { return }
        guard let uid = Auth.auth().currentUser?.uid else { canChat = false; return }
        guard messageListener == nil else { return }
        isLoading = true
        meetingListener = db.collection("meetings").document(meetingID)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    let members = snapshot?.data()?["meetingMembers"] as? [String] ?? []
                    self.canChat = snapshot?.exists == true && members.contains(uid)
                    if !self.canChat {
                        self.errorMessage = "이 모임의 채팅방에 더 이상 접근할 수 없습니다."
                        self.messages = []
                        self.messageListener?.remove()
                        self.messageListener = nil
                    } else {
                        self.loadNames(for: members)
                    }
                }
            }
        messageListener = db.collection("meetings").document(meetingID)
            .collection("messages")
            .order(by: "sequence", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = "메시지를 불러오지 못했습니다: \(error.localizedDescription)"
                        return
                    }
                    let recent = snapshot?.documents ?? []
                    if self.olderMessages.isEmpty {
                        self.oldestDocument = recent.last
                        self.hasOlderMessages = recent.count == 100
                    }
                    self.merge(recent.compactMap(Self.decode))
                    self.loadNames(for: Array(Set(self.messages.map(\.senderID))))
                }
            }
    }

    func stop() {
        meetingListener?.remove()
        meetingListener = nil
        messageListener?.remove()
        messageListener = nil
    }

    func loadOlder() async {
        guard !isLoadingOlder, hasOlderMessages, let oldestDocument else { return }
        isLoadingOlder = true
        do {
            let snapshot = try await db.collection("meetings").document(meetingID)
                .collection("messages")
                .order(by: "sequence", descending: true)
                .start(afterDocument: oldestDocument)
                .limit(to: 100)
                .getDocuments()
            if let last = snapshot.documents.last { self.oldestDocument = last }
            hasOlderMessages = snapshot.documents.count == 100
            olderMessages.append(contentsOf: snapshot.documents.compactMap(Self.decode))
            merge([])
            loadNames(for: Array(Set(messages.map(\.senderID))))
        } catch {
            errorMessage = "이전 메시지를 불러오지 못했습니다: \(error.localizedDescription)"
        }
        isLoadingOlder = false
    }

    func send() async {
        guard !ChatKeyboardUITest.isEnabled else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canChat, !isSending, !text.isEmpty else { return }
        guard text.utf16.count <= 2000 else {
            errorMessage = "메시지는 2000자까지 입력할 수 있습니다."
            return
        }
        isSending = true
        errorMessage = nil
        let messageID: String
        if pendingText == text, let pendingMessageID {
            messageID = pendingMessageID
        } else {
            messageID = UUID().uuidString
            pendingMessageID = messageID
            pendingText = text
        }
        do {
            let result = try await Functions.functions()
                .httpsCallable("sendMeetingChatMessage")
                .call(["meetingId": meetingID, "messageId": messageID, "text": text])
            guard (result.data as? [String: Any])?["sent"] as? Bool == true else {
                throw NSError(domain: "MeetingChat", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "메시지 전송 결과를 확인할 수 없습니다."])
            }
            if draft.trimmingCharacters(in: .whitespacesAndNewlines) == text { draft = "" }
            pendingMessageID = nil
            pendingText = nil
        } catch {
            errorMessage = "전송하지 못했습니다. 다시 시도해 주세요. \(error.localizedDescription)"
        }
        isSending = false
    }

    func markLatestRead() {
        guard !ChatKeyboardUITest.isEnabled else { return }
        guard canChat, let id = messages.last?.id, id != lastRequestedReadID else { return }
        lastRequestedReadID = id
        Task {
            do {
                _ = try await Functions.functions()
                    .httpsCallable("markMeetingChatRead")
                    .call(["meetingId": meetingID, "messageId": id])
                didRetryRead = false
            } catch {
                if !didRetryRead {
                    didRetryRead = true
                    lastRequestedReadID = nil
                }
            }
        }
    }

    private func loadNames(for memberIDs: [String]) {
        for id in memberIDs where memberNames[id] == nil {
            memberNames[id] = "멤버"
            db.collection("users").document(id).getDocument { [weak self] doc, _ in
                DispatchQueue.main.async {
                    self?.memberNames[id] = doc?.data()?["name"] as? String ?? "멤버"
                }
            }
        }
    }

    private static func decode(_ doc: QueryDocumentSnapshot) -> MeetingChatMessage? {
        let data = doc.data()
        guard let sender = data["senderId"] as? String, !sender.isEmpty,
              let text = data["text"] as? String else { return nil }
        return MeetingChatMessage(
            id: doc.documentID, senderID: sender,
            text: text,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            sequence: data["sequence"] as? Int ?? 0
        )
    }

    private func merge(_ recent: [MeetingChatMessage]) {
        var byID = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        for message in olderMessages + recent { byID[message.id] = message }
        messages = byID.values.sorted { $0.sequence < $1.sequence }
    }
}

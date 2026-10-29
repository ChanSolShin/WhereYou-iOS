import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

enum MeetingChatDeliveryState: Equatable, Sendable {
    case queued
    case sending
    case sent
    case failed(String)
}

struct MeetingChatMessage: Identifiable, Equatable, Sendable {
    let id: String
    let senderID: String
    let text: String
    let createdAt: Date?
    let sequence: Int
    var deliveryState: MeetingChatDeliveryState = .sent

    static func decode(_ doc: QueryDocumentSnapshot) -> MeetingChatMessage? {
        let data = doc.data()
        guard let sender = data["senderId"] as? String, !sender.isEmpty,
              let text = data["text"] as? String else { return nil }
        return MeetingChatMessage(
            id: doc.documentID, senderID: sender, text: text,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            sequence: data["sequence"] as? Int ?? 0
        )
    }
}

/// Network operations return values; only the main-actor model publishes UI state.
struct MeetingChatOperations: Sendable {
    var sendMessage: @Sendable (_ meetingID: String, _ messageID: String, _ text: String) async throws -> Void
    var loadOlderMessages: @Sendable (_ meetingID: String, _ beforeSequence: Int) async throws -> [MeetingChatMessage]
    var loadMemberName: @Sendable (_ memberID: String) async -> String
    var markRead: @Sendable (_ meetingID: String, _ messageID: String) async throws -> Void

    static var live: Self {
        Self(
            sendMessage: { meetingID, messageID, text in
                let result = try await Functions.functions()
                    .httpsCallable("sendMeetingChatMessage")
                    .call(["meetingId": meetingID, "messageId": messageID, "text": text])
                guard (result.data as? [String: Any])?["sent"] as? Bool == true else {
                    throw NSError(domain: "MeetingChat", code: 1,
                                  userInfo: [NSLocalizedDescriptionKey: "메시지 전송 결과를 확인할 수 없습니다."])
                }
            },
            loadOlderMessages: { meetingID, beforeSequence in
                let snapshot = try await Firestore.firestore().collection("meetings").document(meetingID)
                    .collection("messages")
                    .order(by: "sequence", descending: true)
                    .start(after: [beforeSequence])
                    .limit(to: 100)
                    .getDocuments()
                return snapshot.documents.compactMap(MeetingChatMessage.decode)
            },
            loadMemberName: { memberID in
                let doc = try? await Firestore.firestore().collection("users").document(memberID).getDocument()
                return doc?.data()?["name"] as? String ?? "멤버"
            },
            markRead: { meetingID, messageID in
                _ = try await Functions.functions()
                    .httpsCallable("markMeetingChatRead")
                    .call(["meetingId": meetingID, "messageId": messageID])
            }
        )
    }
}

@MainActor
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
    private var db: Firestore { Firestore.firestore() }
    private let operations: MeetingChatOperations
    private let userID: @MainActor () -> String?
    private var messageListener: ListenerRegistration?
    private var meetingListener: ListenerRegistration?
    private var lastRequestedReadID: String?
    private var didRetryRead = false
    private var oldestSequence: Int?
    private var olderMessages: [MeetingChatMessage] = []
    private var receivedMessages: [String: MeetingChatMessage] = [:]
    private var outgoingMessages: [MeetingChatMessage] = []
    private var sendQueue: [String] = []
    private var sendTask: Task<Void, Never>?

    var currentUserID: String? { userID() }

    init(meetingID: String, operations: MeetingChatOperations = .live,
         currentUserID: @escaping @MainActor () -> String? = { Auth.auth().currentUser?.uid }) {
        self.meetingID = meetingID
        self.operations = operations
        self.userID = currentUserID
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
        guard let uid = currentUserID else {
            canChat = false
            isLoading = false
            return
        }
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
                    self.receiveRecentMessages((snapshot?.documents ?? []).compactMap(MeetingChatMessage.decode))
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
        guard canChat, !isLoadingOlder, hasOlderMessages, let oldestSequence else { return }
        isLoadingOlder = true
        defer { isLoadingOlder = false }
        do {
            let page = try await operations.loadOlderMessages(meetingID, oldestSequence)
            guard canChat else { return }
            if let oldest = page.map(\.sequence).min() { self.oldestSequence = oldest }
            hasOlderMessages = page.count == 100
            olderMessages.append(contentsOf: page)
            merge([])
            loadNames(for: Array(Set(messages.map(\.senderID))))
        } catch {
            errorMessage = "이전 메시지를 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    /// Snapshot and clear synchronously with the tap. Network completion never edits the draft.
    func send() {
        guard !ChatKeyboardUITest.isEnabled else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canChat, !text.isEmpty else { return }
        guard let uid = currentUserID else {
            errorMessage = "로그인 후 메시지를 보낼 수 있습니다."
            return
        }
        guard text.utf16.count <= 2000 else {
            errorMessage = "메시지는 2000자까지 입력할 수 있습니다."
            return
        }
        let message = MeetingChatMessage(id: UUID().uuidString, senderID: uid, text: text,
                                         createdAt: Date(), sequence: 0, deliveryState: .queued)
        outgoingMessages.append(message)
        sendQueue.append(message.id)
        draft = ""
        errorMessage = nil
        publishMessages()
        startSendingIfNeeded()
    }

    func retry(messageID: String) {
        guard canChat,
              let message = outgoingMessages.first(where: { $0.id == messageID }),
              message.senderID == currentUserID,
              case .failed = message.deliveryState else { return }
        setDelivery(.queued, for: messageID)
        sendQueue.append(messageID)
        startSendingIfNeeded()
    }

    private func startSendingIfNeeded() {
        guard sendTask == nil, !sendQueue.isEmpty else { return }
        isSending = true
        sendTask = Task { await drainSendQueue() }
    }

    private func drainSendQueue() async {
        defer {
            isSending = false
            sendTask = nil
        }
        while !sendQueue.isEmpty {
            let id = sendQueue.removeFirst()
            guard let message = outgoingMessages.first(where: { $0.id == id }) else { continue }
            guard canChat, message.senderID == currentUserID else {
                setDelivery(.failed("로그인 상태와 모임 참여 상태를 확인해 주세요."), for: id)
                continue
            }
            setDelivery(.sending, for: id)
            do {
                try await operations.sendMessage(meetingID, id, message.text)
                setDelivery(.sent, for: id)
            } catch {
                // A snapshot may already have confirmed the write while its HTTP
                // response was lost. Never turn that confirmed message into a failure.
                if receivedMessages[id] == nil {
                    setDelivery(.failed(error.localizedDescription), for: id)
                }
            }
        }
    }

    private func setDelivery(_ state: MeetingChatDeliveryState, for id: String) {
        guard let index = outgoingMessages.firstIndex(where: { $0.id == id }) else { return }
        outgoingMessages[index].deliveryState = state
        publishMessages()
    }

    func markLatestRead() {
        guard !ChatKeyboardUITest.isEnabled else { return }
        guard canChat, let id = receivedMessages.values.max(by: { $0.sequence < $1.sequence })?.id,
              id != lastRequestedReadID else { return }
        lastRequestedReadID = id
        Task {
            do {
                try await operations.markRead(meetingID, id)
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
            Task { [weak self, operations] in
                let name = await operations.loadMemberName(id)
                self?.memberNames[id] = name
            }
        }
    }

    func receiveRecentMessages(_ recent: [MeetingChatMessage]) {
        guard canChat else { return }
        isLoading = false
        if olderMessages.isEmpty {
            oldestSequence = recent.map(\.sequence).min()
            hasOlderMessages = recent.count == 100
        }
        merge(recent)
    }

    private func merge(_ recent: [MeetingChatMessage]) {
        for message in olderMessages + recent { receivedMessages[message.id] = message }
        outgoingMessages.removeAll { receivedMessages[$0.id] != nil }
        sendQueue.removeAll { receivedMessages[$0] != nil }
        publishMessages()
    }

    private func publishMessages() {
        guard canChat else { return }
        messages = receivedMessages.values.sorted { $0.sequence < $1.sequence } + outgoingMessages
    }
}

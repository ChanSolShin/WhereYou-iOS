import XCTest
import Combine
@testable import iOS_Project

final class MeetingChatConcurrencyTests: XCTestCase {
    @MainActor
    func testSendClearsDraftImmediatelyAndMergesEchoBeforeRequestCompletes() async throws {
        let started = expectation(description: "send started")
        let backend = ControlledChatBackend(sendStarted: [started])
        let model = makeModel(backend)
        let observation = observeMainThread(model)
        defer { observation.cancel() }
        model.draft = "안녕하세요"

        model.send()
        XCTAssertEqual(model.draft, "")
        XCTAssertEqual(model.messages.map(\.text), ["안녕하세요"])
        XCTAssertEqual(model.messages.first?.deliveryState, .queued)
        await fulfillment(of: [started], timeout: 3)
        XCTAssertTrue(model.isSending)
        XCTAssertEqual(model.messages.first?.deliveryState, .sending)
        let calls = await backend.sendCalls
        let sent = try XCTUnwrap(calls.first)
        let message = MeetingChatMessage(id: sent.id, senderID: "sender", text: sent.text,
                                         createdAt: Date(), sequence: 1)
        // Firestore can deliver the committed message before the callable returns.
        await Task.detached { await model.receiveRecentMessages([message]) }.value
        XCTAssertEqual(model.messages, [message])
        XCTAssertTrue(model.isSending)

        try await backend.finishSend()
        await waitForQueue(model)
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(model.draft, "")
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.messages, [message])
    }

    @MainActor
    func testRapidSendsQueueInOrderWithoutDuplicatingOrErasingNextDraft() async throws {
        let started = (1...3).map { expectation(description: "send \($0) started") }
        let backend = ControlledChatBackend(sendStarted: started)
        let model = makeModel(backend)
        let observation = observeMainThread(model)
        defer { observation.cancel() }
        model.draft = "첫 메시지"
        model.send()
        await fulfillment(of: [started[0]], timeout: 3)

        for text in ["다음 메시지", "첫 메시지"] {
            model.draft = text
            model.send()
            XCTAssertEqual(model.draft, "")
            // Repeated taps after the same draft has been consumed do not enqueue it again.
            for _ in 0..<30 { model.send() }
        }
        XCTAssertEqual(model.messages.map(\.text), ["첫 메시지", "다음 메시지", "첫 메시지"])
        XCTAssertEqual(model.messages.map(\.deliveryState), [.sending, .queued, .queued])
        model.draft = "아직 작성 중"
        let callsWhileSending = await backend.sendCalls
        XCTAssertEqual(callsWhileSending.count, 1)

        for index in 1..<3 {
            try await backend.finishSend()
            await fulfillment(of: [started[index]], timeout: 3)
            XCTAssertEqual(model.draft, "아직 작성 중")
        }
        try await backend.finishSend()
        await waitForQueue(model)
        let calls = await backend.sendCalls
        XCTAssertEqual(calls.map(\.text), ["첫 메시지", "다음 메시지", "첫 메시지"])
        XCTAssertEqual(Set(calls.map(\.id)).count, 3)
        XCTAssertEqual(model.messages.map(\.deliveryState), [.sent, .sent, .sent])
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(model.draft, "아직 작성 중")
    }

    @MainActor
    func testRetypingSameTextWhileSendingKeepsTheNewDraft() async throws {
        let started = expectation(description: "send started")
        let backend = ControlledChatBackend(sendStarted: [started])
        let model = makeModel(backend)
        model.draft = "같은 내용"
        model.send()
        XCTAssertEqual(model.draft, "")
        await fulfillment(of: [started], timeout: 3)
        model.draft = "같은 내용"
        try await backend.finishSend()
        await waitForQueue(model)
        XCTAssertEqual(model.draft, "같은 내용")
        XCTAssertFalse(model.isSending)
    }

    @MainActor
    func testFailedMessageStaysVisibleAndRetryReusesItsIDWithoutChangingDraft() async throws {
        let started = expectation(description: "send started")
        let retried = expectation(description: "send retried")
        let backend = ControlledChatBackend(sendStarted: [started, retried])
        let model = makeModel(backend)
        let observation = observeMainThread(model)
        defer { observation.cancel() }
        model.draft = "다시 보내기"
        model.send()
        await fulfillment(of: [started], timeout: 3)
        try await backend.finishSend(failing: true)
        await waitForQueue(model)
        let message = try XCTUnwrap(model.messages.first)
        guard case .failed = message.deliveryState else { return XCTFail("Failed message must offer retry") }
        XCTAssertFalse(model.isSending)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.draft, "")

        model.draft = "새로 작성 중"
        for _ in 0..<30 { model.retry(messageID: message.id) }
        await fulfillment(of: [retried], timeout: 3)
        XCTAssertEqual(model.draft, "새로 작성 중")
        XCTAssertEqual(model.messages.count, 1)
        XCTAssertEqual(model.messages.first?.deliveryState, .sending)
        try await backend.finishSend()
        await waitForQueue(model)
        let calls = await backend.sendCalls
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(Set(calls.map(\.id)).count, 1)
        XCTAssertEqual(model.messages.first?.deliveryState, .sent)
        XCTAssertFalse(model.isSending)
        XCTAssertEqual(model.draft, "새로 작성 중")
    }

    @MainActor
    func testConfirmedEchoRemainsSentWhenCallableResponseTimesOut() async throws {
        let started = expectation(description: "send started")
        let backend = ControlledChatBackend(sendStarted: [started])
        let model = makeModel(backend)
        model.draft = "서버에 저장됨"
        model.send()
        await fulfillment(of: [started], timeout: 3)
        let local = try XCTUnwrap(model.messages.first)
        let confirmed = MeetingChatMessage(id: local.id, senderID: local.senderID, text: local.text,
                                            createdAt: Date(), sequence: 1)
        model.receiveRecentMessages([confirmed])
        try await backend.finishSend(failing: true)
        await waitForQueue(model)
        XCTAssertEqual(model.messages, [confirmed])
        XCTAssertFalse(model.isSending)
        XCTAssertNil(model.errorMessage)
    }

    @MainActor
    func testFailedRequestDoesNotBlockTheNextQueuedMessage() async throws {
        let first = expectation(description: "first send")
        let next = expectation(description: "next send")
        let backend = ControlledChatBackend(sendStarted: [first, next])
        let model = makeModel(backend)
        model.draft = "첫 메시지"
        model.send()
        await fulfillment(of: [first], timeout: 3)
        model.draft = "두 번째 메시지"
        model.send()
        try await backend.finishSend(failing: true)
        await fulfillment(of: [next], timeout: 3)
        guard case .failed = model.messages.first?.deliveryState else { return XCTFail("First request should fail") }
        XCTAssertEqual(model.messages.last?.deliveryState, .sending)
        try await backend.finishSend()
        await waitForQueue(model)
        XCTAssertEqual(model.messages.last?.deliveryState, .sent)
        XCTAssertFalse(model.isSending)
    }

    @MainActor
    func testInvalidDraftAndSignedOutUserDoNotEnqueueOrClearText() {
        let backend = ControlledChatBackend()
        let model = makeModel(backend)
        for draft in ["  \n", String(repeating: "가", count: 2001)] {
            model.draft = draft
            model.send()
            XCTAssertEqual(model.draft, draft)
            XCTAssertTrue(model.messages.isEmpty)
            XCTAssertFalse(model.isSending)
        }
        let signedOut = MeetingChatViewModel(meetingID: "room", operations: backend.operations, currentUserID: { nil })
        signedOut.draft = "로그인 필요"
        signedOut.send()
        XCTAssertEqual(signedOut.draft, "로그인 필요")
        XCTAssertTrue(signedOut.messages.isEmpty)
        XCTAssertFalse(signedOut.isSending)
        XCTAssertNotNil(signedOut.errorMessage)
    }

    @MainActor
    func testReadReceiptUsesOnlyServerConfirmedMessages() async throws {
        let started = expectation(description: "send started")
        let read = expectation(description: "confirmed message marked read")
        let backend = ControlledChatBackend(sendStarted: [started], readStarted: read)
        let model = makeModel(backend)
        model.draft = "전송 중인 메시지"
        model.send()
        await fulfillment(of: [started], timeout: 3)
        model.markLatestRead()
        model.receiveRecentMessages(Self.messages(1...3))
        model.markLatestRead()
        await fulfillment(of: [read], timeout: 3)
        try await backend.finishSend()
        await waitForQueue(model)
        // A successful callable response alone still has no server sequence for this message.
        model.markLatestRead()
        let readIDs = await backend.readIDs
        XCTAssertEqual(readIDs, ["message-3"])
    }

    @MainActor
    func testLoadingHistoryAndReceivingMessagesTogetherPublishesOnMainWithoutLosingMessages() async throws {
        let started = expectation(description: "history started")
        let nextStarted = expectation(description: "next history page")
        let namesLoaded = expectation(description: "member name loaded")
        let backend = ControlledChatBackend(olderStarted: [started, nextStarted])
        let model = makeModel(backend)
        let observation = observeMainThread(model)
        let namesObservation = model.$memberNames.filter { $0["sender"] == "테스트 멤버" }
            .first().sink { _ in
                XCTAssertTrue(Thread.isMainThread)
                namesLoaded.fulfill()
            }
        defer { observation.cancel(); namesObservation.cancel() }
        model.receiveRecentMessages(Self.messages(101...200))
        let request = Task.detached { await model.loadOlder() }
        await fulfillment(of: [started], timeout: 3)
        XCTAssertTrue(model.isLoadingOlder)
        await Task.detached { await model.receiveRecentMessages(Self.messages(102...201)) }.value
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 { group.addTask { await model.loadOlder() } }
        }
        let cursorsWhileLoading = await backend.olderCursors
        XCTAssertEqual(cursorsWhileLoading, [101])
        try await backend.finishOlder(with: Array(Self.messages(1...100).reversed()))
        await request.value
        await fulfillment(of: [namesLoaded], timeout: 3)
        XCTAssertFalse(model.isLoadingOlder)
        XCTAssertTrue(model.hasOlderMessages)
        XCTAssertEqual(model.messages.map(\.sequence), Array(1...201))
        XCTAssertEqual(Set(model.messages.map(\.id)).count, 201)

        let nextPage = Task.detached { await model.loadOlder() }
        await fulfillment(of: [nextStarted], timeout: 3)
        try await backend.finishOlder(with: [])
        await nextPage.value
        let cursors = await backend.olderCursors
        XCTAssertEqual(cursors, [101, 1])
        XCTAssertFalse(model.hasOlderMessages)
        XCTAssertFalse(model.isLoadingOlder)
        XCTAssertEqual(model.messages.count, 201)
    }

    @MainActor
    func testFailedHistoryRequestCanRetryWithoutAdvancingCursor() async throws {
        let started = expectation(description: "history started")
        let retried = expectation(description: "history retried")
        let backend = ControlledChatBackend(olderStarted: [started, retried])
        let model = makeModel(backend)
        let observation = observeMainThread(model)
        defer { observation.cancel() }
        let recent = Self.messages(101...200)
        model.receiveRecentMessages(recent)
        let request = Task.detached { await model.loadOlder() }
        await fulfillment(of: [started], timeout: 3)
        try await backend.finishOlder(failing: true)
        await request.value
        XCTAssertFalse(model.isLoadingOlder)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(model.messages, recent)

        model.errorMessage = nil
        let retry = Task.detached { await model.loadOlder() }
        await fulfillment(of: [retried], timeout: 3)
        try await backend.finishOlder(with: Self.messages(99...100))
        await retry.value
        let cursors = await backend.olderCursors
        XCTAssertEqual(cursors, [101, 101])
        XCTAssertFalse(model.isLoadingOlder)
        XCTAssertFalse(model.hasOlderMessages)
        XCTAssertEqual(model.messages.map(\.sequence), Array(99...200))
    }

    @MainActor
    private func makeModel(_ backend: ControlledChatBackend) -> MeetingChatViewModel {
        MeetingChatViewModel(meetingID: "room", operations: backend.operations, currentUserID: { "sender" })
    }

    @MainActor
    private func waitForQueue(_ model: MeetingChatViewModel) async {
        let finished = expectation(description: "send queue drained")
        let observation = model.$isSending.filter { !$0 }.first().sink { _ in finished.fulfill() }
        await fulfillment(of: [finished], timeout: 3)
        observation.cancel()
    }

    @MainActor
    private func observeMainThread(_ model: MeetingChatViewModel) -> AnyCancellable {
        // Do not use receive(on:) here: it would hide the regression at its source.
        model.objectWillChange.sink {
            XCTAssertTrue(Thread.isMainThread, "Every observable chat change must originate on the main thread")
        }
    }

    private static func messages(_ range: ClosedRange<Int>) -> [MeetingChatMessage] {
        range.map { MeetingChatMessage(id: "message-\($0)", senderID: "sender", text: "메시지 \($0)",
                                      createdAt: Date(timeIntervalSince1970: Double($0)), sequence: $0) }
    }
}

/// Deliberately completes requests on a background queue, without production I/O.
private actor ControlledChatBackend {
    struct SendCall: Sendable {
        let id: String
        let text: String
    }
    private(set) var sendCalls: [SendCall] = []
    private(set) var olderCursors: [Int] = []
    private(set) var readIDs: [String] = []
    private let readStarted: XCTestExpectation?
    private let sendStarted: [XCTestExpectation]
    private let olderStarted: [XCTestExpectation]
    private var sendContinuations: [CheckedContinuation<Void, Error>] = []
    private var olderContinuations: [CheckedContinuation<[MeetingChatMessage], Error>] = []

    init(sendStarted: [XCTestExpectation] = [], olderStarted: [XCTestExpectation] = [],
         readStarted: XCTestExpectation? = nil) {
        self.readStarted = readStarted
        self.sendStarted = sendStarted
        self.olderStarted = olderStarted
    }

    nonisolated var operations: MeetingChatOperations {
        MeetingChatOperations(
            sendMessage: { _, id, text in try await self.send(id: id, text: text) },
            loadOlderMessages: { _, cursor in try await self.loadOlder(before: cursor) },
            loadMemberName: { _ in
                await withCheckedContinuation { continuation in
                    DispatchQueue.global().async { continuation.resume(returning: "테스트 멤버") }
                }
            },
            markRead: { _, id in await self.recordRead(id) }
        )
    }

    private func recordRead(_ id: String) {
        readIDs.append(id)
        readStarted?.fulfill()
    }

    private func send(id: String, text: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sendCalls.append(SendCall(id: id, text: text))
            sendContinuations.append(continuation)
            if sendStarted.indices.contains(sendCalls.count - 1) { sendStarted[sendCalls.count - 1].fulfill() }
        }
    }

    private func loadOlder(before cursor: Int) async throws -> [MeetingChatMessage] {
        try await withCheckedThrowingContinuation { continuation in
            olderCursors.append(cursor)
            olderContinuations.append(continuation)
            if olderStarted.indices.contains(olderCursors.count - 1) { olderStarted[olderCursors.count - 1].fulfill() }
        }
    }

    func finishSend(failing: Bool = false) throws {
        let continuation = try XCTUnwrap(sendContinuations.first)
        sendContinuations.removeFirst()
        DispatchQueue.global().async {
            if failing { continuation.resume(throwing: URLError(.timedOut)) }
            else { continuation.resume() }
        }
    }

    func finishOlder(with messages: [MeetingChatMessage] = [], failing: Bool = false) throws {
        let continuation = try XCTUnwrap(olderContinuations.first)
        olderContinuations.removeFirst()
        DispatchQueue.global().async {
            if failing { continuation.resume(throwing: URLError(.notConnectedToInternet)) }
            else { continuation.resume(returning: messages) }
        }
    }
}

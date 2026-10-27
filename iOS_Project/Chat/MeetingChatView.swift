import SwiftUI
import FirebaseAuth
import UIKit

struct MeetingChatListView: View {
    @EnvironmentObject private var chatStore: MeetingChatStore
    @EnvironmentObject private var router: AppRouter
    @Binding var isTabBarHidden: Bool
    @State private var path: [String] = []

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                GlassBackdrop()
                if chatStore.isLoading {
                    ProgressView("채팅방을 불러오는 중...")
                } else if let error = chatStore.errorMessage {
                    ChatEmptyState(title: "채팅방을 불러올 수 없어요", icon: "wifi.exclamationmark", detail: error)
                } else if chatStore.rooms.isEmpty {
                    ChatEmptyState(title: "채팅방이 없어요", icon: "bubble.left.and.bubble.right", detail: "모임에 참여하면 이곳에 채팅방이 나타납니다.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatStore.rooms) { room in
                                Button {
                                    isTabBarHidden = true
                                    path.append(room.id)
                                } label: {
                                    roomRow(room)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("채팅")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.hidden, for: .navigationBar)
            .glassBarBackdrop()
            .navigationDestination(for: String.self) { id in
                Group {
                    if let room = chatStore.rooms.first(where: { $0.id == id }) {
                        MeetingChatView(meetingID: id, meetingTitle: room.meeting.title)
                            .id(id)
                    } else if chatStore.isLoading {
                        ProgressView("채팅방을 불러오는 중...")
                    } else if let error = chatStore.errorMessage {
                        ChatEmptyState(title: "채팅방을 불러올 수 없어요", icon: "wifi.exclamationmark", detail: error)
                    } else {
                        ChatEmptyState(title: "채팅방에 접근할 수 없어요", icon: "bubble.left.slash", detail: "모임이 종료되었거나 참여 중인 멤버가 아닙니다.")
                    }
                }
                .background { GlassBackdrop() }
            }
        }
        .onChange(of: path) { isTabBarHidden = !$0.isEmpty }
        .onReceive(router.$pendingRoute) { destination in
            guard case .meetingChat(let id) = destination else { return }
            // The room list can still be loading on a cold launch. Keep the
            // destination mounted so it opens when membership data arrives.
            DispatchQueue.main.async {
                guard router.pendingRoute == destination else { return }
                path = [id]
                isTabBarHidden = true
                router.consume(.meetingChat(id: id))
            }
        }
        .onReceive(router.$popToRootTab) { tab in
            guard tab == .chat else { return }
            path = []
            isTabBarHidden = false
            router.consumePop(for: .chat)
        }
    }

    private func roomRow(_ room: MeetingChatRoom) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(GlassTheme.blue)
                .frame(width: 40, height: 40)
                .glassSurface(radius: 14)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(room.meeting.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if room.unreadCount > 0 { ChatUnreadBadge(count: room.unreadCount) }
                }
                Text("\(room.meeting.date, formatter: dateFormatter) · \(room.meeting.meetingMemberIDs.count)명")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(room.meeting.meetingAddress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(room.lastMessage ?? "아직 메시지가 없어요. 대화를 시작해 보세요.")
                    .font(.subheadline)
                    .foregroundStyle(room.lastMessage == nil ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 16)
    }
}

struct ChatUnreadBadge: View {
    let count: Int

    var body: some View {
        Text(ChatCountLabel.text(count))
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(minWidth: 22, minHeight: 22)
            .background(Color.red, in: Capsule())
            .accessibilityLabel("읽지 않은 메시지 \(count)개")
    }
}

struct MeetingChatView: View {
    @StateObject private var viewModel: MeetingChatViewModel
    let meetingTitle: String
    @FocusState private var isInputFocused: Bool
    @State private var visibilityOwner = UUID()

    init(meetingID: String, meetingTitle: String) {
        _viewModel = StateObject(wrappedValue: MeetingChatViewModel(meetingID: meetingID))
        self.meetingTitle = meetingTitle
    }

    var body: some View {
        ChatKeyboardLayout(
            messages: viewModel.messages,
            memberNames: viewModel.memberNames,
            currentUserID: Auth.auth().currentUser?.uid,
            hasOlderMessages: viewModel.hasOlderMessages,
            isLoadingOlder: viewModel.isLoadingOlder,
            showsMessages: viewModel.canChat && !viewModel.isLoading && !viewModel.messages.isEmpty,
            canCompose: viewModel.canChat,
            composer: AnyView(composer),
            emptyState: AnyView(emptyState),
            messageRow: { AnyView(messageRow($0)) },
            loadOlder: { Task { await viewModel.loadOlder() } },
            reachedLatest: { viewModel.markLatestRead() },
            dismissKeyboard: { isInputFocused = false }
        )
        // UIKit owns keyboard avoidance here; only its keyboard layout guide moves the composer.
        .ignoresSafeArea(.keyboard)
        .ignoresSafeArea(.container, edges: .bottom)
        .background { GlassBackdrop() }
        .navigationTitle(meetingTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .glassBarBackdrop()
        .onAppear {
            AppRouter.shared.chatDidAppear(id: viewModel.meetingID, owner: visibilityOwner)
            viewModel.start()
            viewModel.markLatestRead()
        }
        .onDisappear {
            AppRouter.shared.chatDidDisappear(owner: visibilityOwner)
            viewModel.stop()
        }
        .alert("채팅 오류", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "다시 시도해 주세요.")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !viewModel.canChat {
            ChatEmptyState(title: "채팅할 수 없어요", icon: "lock.fill", detail: "모임이 끝났거나 멤버에서 제외되었습니다.")
        } else if viewModel.isLoading {
            ProgressView("메시지를 불러오는 중...")
        } else {
            ChatEmptyState(title: "첫 메시지를 보내보세요", icon: "bubble.left.and.bubble.right")
        }
    }

    private var composer: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if viewModel.draft.utf16.count > 1800 {
                Text("\(viewModel.draft.utf16.count)/2000")
                    .font(.caption2)
                    .foregroundStyle(viewModel.draft.utf16.count > 2000 ? Color.red : Color.secondary)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("메시지 입력", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($isInputFocused)
                    .accessibilityIdentifier("chat-composer-input")
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .glassSurface(radius: 20)
                Button {
                    Task { await viewModel.send() }
                } label: {
                    Group {
                        if viewModel.isSending {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                        }
                    }
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.white)
                    .background(GlassTheme.blue, in: Circle())
                }
                .disabled(viewModel.isSending || viewModel.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.draft.utf16.count > 2000)
                .accessibilityLabel("메시지 보내기")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
    }

    private func messageRow(_ message: MeetingChatMessage) -> some View {
        let mine = message.senderID == Auth.auth().currentUser?.uid
        return HStack(alignment: .bottom) {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 3) {
                if !mine {
                    Text(viewModel.memberNames[message.senderID] ?? "멤버")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(message.text)
                    .accessibilityIdentifier("chat-message-\(message.id)")
                    .font(.body)
                    .foregroundStyle(mine ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(mine ? GlassTheme.blue : Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
                if let date = message.createdAt {
                    Text(date, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !mine { Spacer(minLength: 50) }
        }
    }

}

private struct ChatEmptyState: View {
    let title: String
    let icon: String
    var detail: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.largeTitle).foregroundStyle(GlassTheme.blue)
            Text(title).font(.headline)
            if let detail {
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

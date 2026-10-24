//
//  AddSelectedFriend.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/31/24.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

struct AddSelectedFriend: View {
    @StateObject private var friendListViewModel = FriendListViewModel()
    @StateObject private var invitationStatus = MeetingInvitationStatus()
    var meeting: MeetingListModel
    
    @State private var selectedFriends: [String] = []
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isSending = false
    @State private var sendingMessage = ""
    @Environment(\.dismiss) private var dismiss

    private var availableFriends: [FriendModel] {
        friendListViewModel.friends.filter { !invitationStatus.memberIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackdrop()
                friendListContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("멤버 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("닫기") { dismiss() }
                        .disabled(isSending)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 6) {
                    Button(action: sendMeetingInvitations) {
                        Group {
                            if isSending {
                                ProgressView()
                            } else {
                                Image(systemName: "plus")
                                    .font(.system(size: 24, weight: .semibold))
                            }
                        }
                        .frame(width: 56, height: 56)
                        .foregroundStyle(GlassTheme.blue)
                        .glassSubtleCircle()
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedFriends.isEmpty || !invitationStatus.isReady || isSending)
                    .accessibilityLabel(isSending ? "초대 요청 전송 중" : "선택한 친구 초대")

                    Text(isSending
                         ? sendingMessage
                         : selectedFriends.isEmpty ? "친구를 선택해 주세요" : "\(selectedFriends.count)명 초대하기")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.updatesFrequently)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .onAppear {
                invitationStatus.observe(meetingID: meeting.id, currentUserID: Auth.auth().currentUser?.uid)
            }
            .onDisappear {
                invitationStatus.stop()
            }
            .onReceive(invitationStatus.$memberIDs) { memberIDs in
                selectedFriends.removeAll { memberIDs.contains($0) }
            }
            .onReceive(invitationStatus.$requestedIDs) { requestedIDs in
                selectedFriends.removeAll { requestedIDs.contains($0) }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
            }
        }
        .interactiveDismissDisabled(isSending)
    }

    @ViewBuilder
    private var friendListContent: some View {
        if (friendListViewModel.isLoadingFriends && friendListViewModel.friends.isEmpty)
            || invitationStatus.isLoading {
            ProgressView("초대 가능한 친구를 확인하는 중...")
        } else if let error = friendListViewModel.friendsLoadError,
                  friendListViewModel.friends.isEmpty {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.secondary)
                Button("다시 시도") {
                    friendListViewModel.observeFriends()
                }
                .glassSecondaryAction()
            }
        } else if let error = invitationStatus.errorMessage {
            VStack(spacing: 12) {
                Text(error)
                    .foregroundStyle(.secondary)
                Button("다시 시도") {
                    invitationStatus.observe(meetingID: meeting.id, currentUserID: Auth.auth().currentUser?.uid)
                }
                .glassSecondaryAction()
            }
        } else if availableFriends.isEmpty {
            Text("초대할 친구가 없습니다.")
                .foregroundStyle(.secondary)
        } else {
            List(availableFriends) { friend in
                FriendRow(
                    friend: friend,
                    isSelected: selectedFriends.contains(friend.id),
                    isRequested: invitationStatus.requestedIDs.contains(friend.id)
                ) {
                    toggleSelection(for: friend)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
    
    func toggleSelection(for friend: FriendModel) {
        guard invitationStatus.isReady,
              !invitationStatus.memberIDs.contains(friend.id),
              !invitationStatus.requestedIDs.contains(friend.id) else { return }
        if let index = selectedFriends.firstIndex(of: friend.id) {
            selectedFriends.remove(at: index)
        } else {
            selectedFriends.append(friend.id)
        }
    }
    
    func sendMeetingInvitations() {
        guard invitationStatus.isReady, !isSending else { return }
        let friendIDs = selectedFriends.filter {
            !invitationStatus.memberIDs.contains($0) && !invitationStatus.requestedIDs.contains($0)
        }
        guard !friendIDs.isEmpty else { return }
        guard let currentUserID = Auth.auth().currentUser?.uid else {
            alertMessage = "로그인 후 초대할 수 있습니다."
            showAlert = true
            return
        }

        // Give feedback before any network request starts.
        isSending = true
        sendingMessage = "초대 요청을 확인하고 있어요..."

        let db = Firestore.firestore()
        let loadGroup = DispatchGroup()
        var currentMemberIDs: Set<String>?
        var pendingRecipientIDs: Set<String>?
        var senderName = friendListViewModel.currentUserName
        var loadError: String?

        loadGroup.enter()
        db.collection("meetings").document(meeting.id).getDocument(source: .server) { document, error in
            DispatchQueue.main.async {
                if error == nil, let document, document.exists {
                    currentMemberIDs = Set(document.data()?["meetingMembers"] as? [String] ?? [])
                } else {
                    loadError = "모임 정보를 확인하지 못했습니다. 네트워크 연결을 확인해 주세요."
                }
                loadGroup.leave()
            }
        }

        loadGroup.enter()
        db.collection("meetingRequests")
            .whereField("meetingID", isEqualTo: meeting.id)
            .getDocuments(source: .server) { snapshot, error in
                DispatchQueue.main.async {
                    if error == nil, let snapshot {
                        pendingRecipientIDs = Set(snapshot.documents.compactMap { document -> String? in
                            let data = document.data()
                            guard data["status"] as? String == "pending" else { return nil }
                            return data["toUserID"] as? String
                        })
                    } else {
                        loadError = "기존 초대 요청을 확인하지 못했습니다. 네트워크 연결을 확인해 주세요."
                    }
                    loadGroup.leave()
                }
            }

        if senderName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            loadGroup.enter()
            db.collection("users").document(currentUserID).getDocument(source: .server) { document, error in
                DispatchQueue.main.async {
                    if error == nil, let document {
                        senderName = document.data()?["name"] as? String
                    }
                    if senderName == nil {
                        loadError = "내 정보를 불러오지 못했습니다. 다시 시도해 주세요."
                    }
                    loadGroup.leave()
                }
            }
        }

        loadGroup.notify(queue: .main) {
            guard let currentMemberIDs,
                  let pendingRecipientIDs,
                  let senderName,
                  !senderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                isSending = false
                alertMessage = loadError ?? "초대에 필요한 정보를 불러오지 못했습니다."
                showAlert = true
                return
            }

            let candidates = friendIDs.filter { !currentMemberIDs.contains($0) }
            let alreadyMemberCount = friendIDs.count - candidates.count
            let toInvite = candidates.filter { !pendingRecipientIDs.contains($0) }
            let alreadyRequestedCount = candidates.count - toInvite.count
            pendingRecipientIDs.intersection(candidates).forEach { invitationStatus.markRequested($0) }

            if toInvite.isEmpty {
                isSending = false
                selectedFriends = []
                alertMessage = alreadyRequestedCount > 0
                    ? "선택한 친구에게 이미 초대 요청을 보냈습니다."
                    : "선택한 친구가 이미 모임에 참여 중입니다."
                showAlert = true
                return
            }

            sendingMessage = "초대 요청을 보내고 있어요..."
            let batch = db.batch()
            for friendID in toInvite {
                let request = db.collection("meetingRequests").document()
                batch.setData([
                    "fromUserID": currentUserID,
                    "fromUserName": senderName,
                    "toUserID": friendID,
                    "meetingName": meeting.title,
                    "status": "pending",
                    "meetingID": meeting.id
                ], forDocument: request)
            }

            batch.commit { error in
                DispatchQueue.main.async {
                    isSending = false
                    if error == nil {
                        toInvite.forEach { invitationStatus.markRequested($0) }
                        selectedFriends = []
                        var results = ["\(toInvite.count)명에게 초대 요청을 보냈습니다."]
                        if alreadyRequestedCount > 0 {
                            results.append("\(alreadyRequestedCount)명은 이미 요청된 상태입니다.")
                        }
                        if alreadyMemberCount > 0 {
                            results.append("\(alreadyMemberCount)명은 이미 모임에 참여 중입니다.")
                        }
                        alertMessage = results.joined(separator: "\n")
                    } else {
                        alertMessage = "초대 요청을 보내지 못했습니다. 네트워크 연결을 확인한 뒤 다시 시도해 주세요."
                    }
                    showAlert = true
                }
            }
        }
    }

    struct FriendRow: View {
        var friend: FriendModel
        var isSelected: Bool
        var isRequested: Bool
        var onTap: () -> Void

        var body: some View {
            Button(action: onTap) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(friend.name).font(.headline)
                        Text(friend.email).font(.subheadline)
                    }
                    Spacer()
                    if isRequested {
                        Text("요청됨")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .contentShape(Rectangle())
                .glassSurface(radius: 10)
            }
            .buttonStyle(.plain)
            .disabled(isRequested)
            .accessibilityValue(isRequested ? "요청됨" : (isSelected ? "선택됨" : "선택되지 않음"))
        }
    }
}

private final class MeetingInvitationStatus: ObservableObject {
    @Published private(set) var memberIDs: Set<String> = []
    @Published private(set) var requestedIDs: Set<String> = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    var isReady: Bool { !isLoading && errorMessage == nil }

    private var meetingListener: ListenerRegistration?
    private var requestsListener: ListenerRegistration?
    private var generation = 0
    private var hasLoadedMeeting = false
    private var hasLoadedRequests = false
    private var meetingError: String?
    private var requestsError: String?
    private var locallySentIDs: Set<String> = []

    func observe(meetingID: String, currentUserID: String?) {
        stop()
        memberIDs = []
        requestedIDs = []
        locallySentIDs = []
        hasLoadedMeeting = false
        hasLoadedRequests = false
        meetingError = nil
        requestsError = nil
        isLoading = true
        errorMessage = nil

        guard currentUserID != nil else {
            isLoading = false
            errorMessage = "로그인 후 친구를 초대할 수 있습니다."
            return
        }

        let currentGeneration = generation
        let db = Firestore.firestore()
        meetingListener = db.collection("meetings").document(meetingID)
            .addSnapshotListener { [weak self] document, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    guard error == nil, let document, document.exists else {
                        self.meetingError = "모임 멤버 정보를 불러오지 못했습니다."
                        self.refreshLoadingState()
                        return
                    }
                    self.memberIDs = Set(document.data()?["meetingMembers"] as? [String] ?? [])
                    self.hasLoadedMeeting = true
                    self.meetingError = nil
                    self.refreshLoadingState()
                }
            }

        requestsListener = db.collection("meetingRequests")
            .whereField("meetingID", isEqualTo: meetingID)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == currentGeneration else { return }
                    guard error == nil, let snapshot else {
                        self.requestsError = "초대 요청 내역을 불러오지 못했습니다."
                        self.refreshLoadingState()
                        return
                    }
                    let remoteIDs = Set(snapshot.documents.compactMap { document -> String? in
                        let data = document.data()
                        guard data["status"] as? String == "pending" else { return nil }
                        return data["toUserID"] as? String
                    })
                    self.locallySentIDs.subtract(remoteIDs)
                    self.requestedIDs = remoteIDs.union(self.locallySentIDs)
                    self.hasLoadedRequests = true
                    self.requestsError = nil
                    self.refreshLoadingState()
                }
            }
    }

    func markRequested(_ friendID: String) {
        locallySentIDs.insert(friendID)
        requestedIDs.insert(friendID)
    }

    func stop() {
        generation += 1
        meetingListener?.remove()
        requestsListener?.remove()
        meetingListener = nil
        requestsListener = nil
    }

    private func refreshLoadingState() {
        errorMessage = meetingError ?? requestsError
        isLoading = errorMessage == nil && !(hasLoadedMeeting && hasLoadedRequests)
    }

    deinit {
        meetingListener?.remove()
        requestsListener?.remove()
    }
}

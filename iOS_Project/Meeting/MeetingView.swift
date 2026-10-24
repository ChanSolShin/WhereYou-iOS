//
//  MeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import Combine
import UIKit

struct MeetingView: View {
    @Environment(\.dismiss) var dismiss
    var meeting: MeetingListModel
    @ObservedObject var meetingViewModel: MeetingViewModel
    @State var meetingDate: Date? = nil
    @State private var showingAddFriendModal = false
    @State private var leaderSelctionModal = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showActionSheet = false
    @State private var showingEditMeetingModal = false
    @State private var showingKickOutModal = false
    @State private var selectedMemberID: String? = nil
    @State private var selectedButton: String? = nil
    @State private var notificationRecipient: MeetingNotificationRecipient?
    @State private var radialMemberID: String?
    @State private var radialHighlightedPreset: MeetingNotificationPreset?
    @State private var isSendingNotification = false
    @State private var toastMessage: String?
    // 강퇴 알림 1회성 표시 플래그
    @State private var showKickedAlert: Bool = false
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(meetingViewModel.meetingDate != nil ? formattedDate(meetingViewModel.meetingDate!) : "모임시간: 불러오는 중...")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 10)
            
            if meetingViewModel.locationCoordinator.authorizationStatus == .authorizedAlways {
                MeetingMapView(
                    selectedUserLocation: $meetingViewModel.selectedUserLocation,
                    meeting: MeetingModel(
                        id: meeting.id,
                        title: meeting.title,
                        date: meeting.date,
                        meetingAddress: meeting.meetingAddress,
                        meetingLocation: meeting.meetingLocation,
                        meetingMemberIDs: meeting.meetingMemberIDs,
                        meetingMasterID: meeting.meetingMasterID,
                        isLocationTrackingEnabled: meeting.isLocationTrackingEnabled
                    ),
                    meetingViewModel: meetingViewModel
                )
                .frame(height: min(450, UIScreen.main.bounds.height * 0.50))
            } else {
                VStack(spacing: 12) {
                    Text("위치 권한이 필요합니다")
                        .font(.headline)
                    Text("상대방의 위치를 보려면, 내 위치도 공유해야 합니다.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                    Button("설정으로 이동") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                    .glassSecondaryAction()
                    .controlSize(.large)
                }
                .frame(height: min(450, UIScreen.main.bounds.height * 0.50))
                .glassSurface(radius: 16)
                .padding(.horizontal, 16)
            }
            
            Button(action: {
                meetingViewModel.stopTrackingMember()
                meetingViewModel.selectedUserLocation = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    meetingViewModel.selectedUserLocation = meeting.meetingLocation
                }

                selectedMemberID = nil
                selectedButton = "meetingLocation"
            }) {
                Text("모임장소")
            }
            .glassSelectionAction(selected: selectedButton == "meetingLocation")
            .controlSize(.large)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(sortedMemberIDs(), id: \.self) { memberID in
                        ZStack {
                            Text(meetingViewModel.meetingMemberNames[memberID] ?? "멤버 불러오는 중 ...")

                            if memberID == (meetingViewModel.meetingMasterID ?? meeting.meetingMasterID) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                    .offset(x: 0, y: -40)
                                    .zIndex(1)
                            }
                        }
                        .fontWeight(selectedMemberID == memberID ? .semibold : .regular)
                        .foregroundColor(selectedMemberID == memberID ? GlassTheme.blue : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(minHeight: 44)
                        .background {
                            if selectedMemberID == memberID {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(GlassTheme.blue.opacity(0.12))
                            }
                        }
                        .glassSurface(radius: 16)
                        .contentShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.vertical, 2)
                        .overlay {
                            MemberTouchCapture(
                                onTap: { selectMemberLocation(memberID) },
                                onHoldStart: { window, anchor in
                                    beginQuickNotification(for: memberID, in: window, anchor: anchor)
                                },
                                onHoldMove: { movement in
                                    guard radialMemberID == memberID else { return }
                                    let highlighted = preset(for: movement)
                                    if highlighted != radialHighlightedPreset {
                                        radialHighlightedPreset = highlighted
                                        MeetingQuickOverlayPresenter.shared.update(highlightedPreset: highlighted)
                                        if highlighted != nil {
                                            UISelectionFeedbackGenerator().selectionChanged()
                                        }
                                    }
                                },
                                onHoldEnd: { movement in
                                    let selectedPreset = preset(for: movement)
                                    let shouldSend = radialMemberID == memberID && canNotify(memberID)
                                    radialMemberID = nil
                                    radialHighlightedPreset = nil
                                    MeetingQuickOverlayPresenter.shared.dismiss()
                                    if shouldSend, let selectedPreset {
                                        Task { await sendQuickNotification(selectedPreset, to: memberID) }
                                    }
                                },
                                onHoldCancel: {
                                    guard radialMemberID == memberID else { return }
                                    radialMemberID = nil
                                    radialHighlightedPreset = nil
                                    MeetingQuickOverlayPresenter.shared.dismiss()
                                }
                            )
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(meetingViewModel.meetingMemberNames[memberID] ?? "모임 멤버")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction {
                            selectMemberLocation(memberID)
                        }
                        .accessibilityActions {
                            if memberID != Auth.auth().currentUser?.uid {
                                Button("빠른 알림 보내기") {
                                    openNotificationSheet(for: memberID)
                                }
                            }
                        }
                        .accessibilityHint(memberID == Auth.auth().currentUser?.uid
                                           ? "한 번 탭하면 내 위치 확인"
                                           : "한 번 탭하면 위치 확인, 길게 누르면 빠른 알림")
                    }
                }
                .padding(.horizontal)
                .padding(.horizontal)
                .padding(.top, 35)
            }

            Text(Auth.auth().currentUser == nil
                 ? "로그인 후 알림을 보낼 수 있어요"
                 : "탭하면 위치 확인 · 다른 멤버를 길게 누르면 빠른 알림")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(GlassBackdrop())
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .glassSurface(radius: 18)
                    .padding(.bottom, 14)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .onAppear {
            meetingViewModel.errorMessage = nil
            meetingViewModel.fetchMeetingData(meetingID: meeting.id)
            meetingViewModel.stopTrackingMember()
            selectedMemberID = nil
            selectedButton = nil
            radialMemberID = nil
            radialHighlightedPreset = nil
            MeetingQuickOverlayPresenter.shared.dismiss()
            meetingViewModel.consumeKickedEvent()   // 이전 화면에서 남아있을 수 있는 isKicked 상태 초기화
            showKickedAlert = false                 // 로컬 1회성 알림 플래그 초기화
        }
        .onDisappear {
            meetingViewModel.stopTrackingMember()
            meetingViewModel.stopMeetingListeners()
            meetingViewModel.consumeKickedEvent()   // 이 화면을 떠날 때 전역 isKicked 상태 정리
            showKickedAlert = false
            radialMemberID = nil
            radialHighlightedPreset = nil
            MeetingQuickOverlayPresenter.shared.dismiss()
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: {
                        if let currentUserID = Auth.auth().currentUser?.uid {
                            if meetingViewModel.isMeetingMaster(meetingID: meeting.id, currentUserID: currentUserID, meetingMasterID: meeting.meetingMasterID) {
                                showingAddFriendModal = true
                            } else {
                                alertMessage = "모임장만 멤버 초대를 할 수 있습니다."
                                showAlert = true
                            }
                        }
                    }) {
                        Image(systemName: "person.badge.plus")
                    }
                    
                    Button(action: {
                        showActionSheet = true
                    }) {
                        Image(systemName: "ellipsis")
                            .rotationEffect(.degrees(90))
                            .imageScale(.large)
                    }
                    .alert("모임 관리", isPresented: $showActionSheet) {
                        if canManageMeeting {
                            Button("모임 정보 수정") { showingEditMeetingModal = true }
                            Button("모임장 변경") { leaderSelctionModal = true }
                            Button("멤버 강퇴하기") { showingKickOutModal = true }
                        }
                        Button("모임 나가기", role: .destructive) {
                            meetingViewModel.leaveMeeting(meetingID: meeting.id)
                            dismiss()
                        }
                        Button("취소", role: .cancel) {}
                    } message: {
                        Text("원하는 작업을 선택하세요")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddFriendModal) {
            AddSelectedFriend(meeting: meeting)
        }
        .sheet(item: $notificationRecipient) { recipient in
            MeetingNotificationSheet(meetingID: meeting.id, recipient: recipient) { message in
                showToast(message)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("알림"), message: Text(alertMessage), dismissButton: .default(Text("확인")))
        }
        .onReceive(meetingViewModel.$errorMessage) { message in
            if let message = message {
                alertMessage = message
                showAlert = true
            }
        }
        .onReceive(meetingViewModel.$currentMemberIDs) { memberIDs in
            if let selectedMemberID, !memberIDs.contains(selectedMemberID) {
                self.selectedMemberID = nil
                selectedButton = nil
                meetingViewModel.stopTrackingMember()
            }
            if let radialMemberID, !memberIDs.contains(radialMemberID) {
                self.radialMemberID = nil
                radialHighlightedPreset = nil
                MeetingQuickOverlayPresenter.shared.dismiss()
            }
            if let notificationRecipient, !memberIDs.contains(notificationRecipient.id) {
                self.notificationRecipient = nil
            }
        }
        // 1회성 알림 표시 (이전 화면에서 남은 true를 방지)
        .onReceive(meetingViewModel.$isKicked) { kicked in
            if kicked && !showKickedAlert {
                showKickedAlert = true
            }
        }
        .alert("모임에서 제외되었습니다.", isPresented: $showKickedAlert) {
            Button("확인") {
                meetingViewModel.consumeKickedEvent() // 이벤트 소비(1회성)
                showKickedAlert = false               // 로컬 플래그 리셋
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showingEditMeetingModal) {
            NavigationStack {
                EditMeetingView(meetingID: meeting.id)
            }
        }
        .sheet(isPresented: $leaderSelctionModal) {
            LeaderSelectionView(meetingID: meeting.id, currentUserID: Auth.auth().currentUser?.uid ?? "")
        }
        .sheet(isPresented: $showingKickOutModal) {
            KickOutMember(meetingID: meeting.id, currentUserID: Auth.auth().currentUser?.uid ?? "")
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일 HH:mm"
        return "모임시간: \(formatter.string(from: date))"
    }

    private func selectMemberLocation(_ memberID: String) {
        if meetingViewModel.trackedMemberID == memberID {
            meetingViewModel.stopTrackingMember()
            selectedMemberID = nil
        } else {
            meetingViewModel.moveToUserLocation(userID: memberID)
            selectedMemberID = memberID
        }
        selectedButton = selectedMemberID == nil ? nil : memberID
    }

    private func openNotificationSheet(for memberID: String) {
        guard canNotify(memberID) else { return }
        notificationRecipient = MeetingNotificationRecipient(
            id: memberID,
            name: meetingViewModel.meetingMemberNames[memberID] ?? "모임 멤버"
        )
    }

    private func beginQuickNotification(for memberID: String, in window: UIWindow, anchor: CGRect) {
        guard canNotify(memberID), !isSendingNotification else { return }
        if radialMemberID != memberID {
            radialMemberID = memberID
            radialHighlightedPreset = nil
            MeetingQuickOverlayPresenter.shared.present(
                in: window,
                anchor: anchor,
                recipientName: meetingViewModel.meetingMemberNames[memberID] ?? "모임 멤버"
            )
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func canNotify(_ memberID: String) -> Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return false }
        return memberID != currentUserID && meetingViewModel.currentMemberIDs.contains(memberID)
    }

    private func preset(for movement: CGSize) -> MeetingNotificationPreset? {
        guard hypot(movement.width, movement.height) > 52 else { return nil }
        if abs(movement.width) > abs(movement.height) {
            return movement.width > 0 ? .almostThere : .whereAreYou
        }
        return movement.height > 0 ? .runningLate : .startingSoon
    }

    @MainActor
    private func sendQuickNotification(_ preset: MeetingNotificationPreset, to memberID: String) async {
        guard canNotify(memberID), !isSendingNotification else { return }
        isSendingNotification = true
        let memberName = meetingViewModel.meetingMemberNames[memberID] ?? "모임 멤버"
        showToast("알림을 보내는 중...")
        do {
            try await MeetingNotificationSender.send(
                meetingID: meeting.id,
                recipientID: memberID,
                preset: preset
            )
            showToast("\(memberName)님에게 ‘\(preset.shortTitle)’ 알림을 보냈어요.")
        } catch {
            toastMessage = nil
            alertMessage = error.localizedDescription
            showAlert = true
        }
        isSendingNotification = false
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if toastMessage == message {
                toastMessage = nil
            }
        }
    }

    private var canManageMeeting: Bool {
        guard let currentUserID = Auth.auth().currentUser?.uid else { return false }
        return meetingViewModel.isMeetingMaster(
            meetingID: meeting.id,
            currentUserID: currentUserID,
            meetingMasterID: meeting.meetingMasterID
        )
    }

    private func sortedMemberIDs() -> [String] {
        let leaderID = meetingViewModel.meetingMasterID ?? meeting.meetingMasterID
        let ids = meetingViewModel.currentMemberIDs
        // 멤버 버튼 순서: 모임장이 항상 첫 번째
        let others = ids.filter { $0 != leaderID }
        let sortedOthers = others.sorted { (a, b) -> Bool in
            let nameA = meetingViewModel.meetingMemberNames[a] ?? ""
            let nameB = meetingViewModel.meetingMemberNames[b] ?? ""
            if nameA.isEmpty || nameB.isEmpty { return a < b }
            return nameA.localizedCaseInsensitiveCompare(nameB) == .orderedAscending
        }
        if ids.contains(leaderID) {
            return [leaderID] + sortedOthers
        } else {
            return sortedOthers
        }
    }
}

/// Keeps a normal tap separate from the hold-and-drag quick notification gesture.
private struct MemberTouchCapture: UIViewRepresentable {
    let onTap: () -> Void
    let onHoldStart: (UIWindow, CGRect) -> Void
    let onHoldMove: (CGSize) -> Void
    let onHoldEnd: (CGSize) -> Void
    let onHoldCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let hold = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleHold(_:))
        )
        hold.minimumPressDuration = 0.6
        hold.allowableMovement = 12

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tap.require(toFail: hold)

        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject {
        var parent: MemberTouchCapture
        private var holdOrigin: CGPoint?

        init(parent: MemberTouchCapture) {
            self.parent = parent
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            parent.onTap()
        }

        @objc func handleHold(_ recognizer: UILongPressGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                holdOrigin = recognizer.location(in: view)
                if let window = view.window {
                    parent.onHoldStart(window, view.convert(view.bounds, to: window))
                }
            case .changed:
                guard let holdOrigin else { return }
                parent.onHoldMove(movement(from: holdOrigin, to: recognizer.location(in: view)))
            case .ended:
                guard let holdOrigin else { return }
                let movement = movement(from: holdOrigin, to: recognizer.location(in: view))
                self.holdOrigin = nil
                parent.onHoldEnd(movement)
            case .cancelled, .failed:
                guard holdOrigin != nil else { return }
                holdOrigin = nil
                parent.onHoldCancel()
            default:
                break
            }
        }

        private func movement(from start: CGPoint, to end: CGPoint) -> CGSize {
            CGSize(width: end.x - start.x, height: end.y - start.y)
        }
    }
}

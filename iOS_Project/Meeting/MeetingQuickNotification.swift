import SwiftUI
import FirebaseAuth
import FirebaseFunctions
import UIKit

enum MeetingNotificationPreset: String, CaseIterable, Identifiable {
    case startingSoon
    case almostThere
    case whereAreYou
    case runningLate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startingSoon: return "곧 시작해요. 서둘러 주세요!"
        case .almostThere: return "저 거의 도착했어요."
        case .whereAreYou: return "어디쯤 오고 있어요?"
        case .runningLate: return "조금 늦을 것 같아요."
        }
    }

    var shortTitle: String {
        switch self {
        case .startingSoon: return "곧 시작해요"
        case .almostThere: return "거의 도착"
        case .whereAreYou: return "어디쯤?"
        case .runningLate: return "조금 늦어요"
        }
    }

    var symbol: String {
        switch self {
        case .startingSoon: return "clock.badge.exclamationmark"
        case .almostThere: return "location.fill"
        case .whereAreYou: return "location.magnifyingglass"
        case .runningLate: return "clock.arrow.circlepath"
        }
    }

    var radialOffset: CGSize {
        switch self {
        case .startingSoon: return CGSize(width: 0, height: -92)
        case .almostThere: return CGSize(width: 92, height: 0)
        case .whereAreYou: return CGSize(width: -92, height: 0)
        case .runningLate: return CGSize(width: 0, height: 92)
        }
    }
}

struct MeetingNotificationRecipient: Identifiable {
    let id: String
    let name: String
}

struct MeetingQuickNotificationMenu: View {
    let recipientName: String
    let highlightedPreset: MeetingNotificationPreset?

    var body: some View {
        ZStack {
            ForEach(MeetingNotificationPreset.allCases) { preset in
                VStack(spacing: 2) {
                    Image(systemName: preset.symbol)
                        .font(.subheadline)
                    Text(preset.shortTitle)
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundColor(highlightedPreset == preset ? .white : .primary)
                .frame(width: 84, height: 54)
                .background {
                    if highlightedPreset == preset {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(GlassTheme.blue)
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(.white.opacity(0.65), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                .offset(preset.radialOffset)
            }

            VStack(spacing: 3) {
                Image(systemName: "bell.badge")
                    .font(.headline)
                Text(recipientName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: 82, height: 62)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        }
        .frame(width: 280, height: 280)
        .accessibilityHidden(true)
    }
}

/// Presents the dimming layer above the tab and navigation controllers while
/// leaving the original long-press recognizer in control of the drag.
@MainActor
final class MeetingQuickOverlayPresenter {
    static let shared = MeetingQuickOverlayPresenter()

    private var host: UIHostingController<MeetingQuickFullScreenOverlay>?
    private var anchor: CGRect = .zero
    private var recipientName = ""
    private var instructionTop: CGFloat = 0

    private init() {}

    func present(in window: UIWindow, anchor: CGRect, recipientName: String) {
        dismiss()
        guard let root = window.rootViewController else { return }

        self.anchor = root.view.convert(anchor, from: window)
        self.recipientName = recipientName
        instructionTop = window.safeAreaInsets.top + 54

        let host = UIHostingController(rootView: overlay(highlightedPreset: nil))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.frame = root.view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.addChild(host)
        root.view.addSubview(host.view)
        host.didMove(toParent: root)
        self.host = host
    }

    func update(highlightedPreset: MeetingNotificationPreset?) {
        host?.rootView = overlay(highlightedPreset: highlightedPreset)
    }

    func dismiss() {
        guard let host else { return }
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
        self.host = nil
    }

    private func overlay(highlightedPreset: MeetingNotificationPreset?) -> MeetingQuickFullScreenOverlay {
        MeetingQuickFullScreenOverlay(
            anchor: anchor,
            recipientName: recipientName,
            highlightedPreset: highlightedPreset,
            instructionTop: instructionTop
        )
    }
}

private struct MeetingQuickFullScreenOverlay: View {
    let anchor: CGRect
    let recipientName: String
    let highlightedPreset: MeetingNotificationPreset?
    let instructionTop: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let xInset = min(135, geometry.size.width / 2)
            let yInset = min(120, geometry.size.height / 2)
            let menuCenter = CGPoint(
                x: min(max(anchor.midX, xInset), geometry.size.width - xInset),
                y: min(max(anchor.midY, yInset), geometry.size.height - yInset)
            )

            ZStack {
                Color.black.opacity(0.28)

                MeetingQuickNotificationMenu(
                    recipientName: recipientName,
                    highlightedPreset: highlightedPreset
                )
                .position(menuCenter)
                .offset(y: 6)

                VStack {
                    Text("방향으로 밀어 선택 · 손을 떼면 전송")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                    Spacer()
                }
                .padding(.top, instructionTop)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum MeetingNotificationSender {
    static func send(meetingID: String, recipientID: String, preset: MeetingNotificationPreset) async throws {
        guard let currentUserID = Auth.auth().currentUser?.uid, currentUserID != recipientID else {
            throw NSError(
                domain: "MeetingNotification",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "자기 자신에게는 알림을 보낼 수 없습니다."]
            )
        }
        let payload = [
            "meetingId": meetingID,
            "recipientId": recipientID,
            "preset": preset.rawValue
        ]
        let result = try await Functions.functions()
            .httpsCallable("sendMeetingMemberNotification")
            .call(payload)
        guard let response = result.data as? [String: Any], response["sent"] as? Bool == true else {
            throw NSError(
                domain: "MeetingNotification",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "알림 전송 결과를 확인할 수 없습니다."]
            )
        }
    }
}

struct MeetingNotificationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let meetingID: String
    let recipient: MeetingNotificationRecipient
    let onSent: (String) -> Void

    @State private var selectedPreset: MeetingNotificationPreset?
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(recipient.name)님에게 보낼 알림을 선택하세요.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(MeetingNotificationPreset.allCases) { preset in
                            Button {
                                selectedPreset = preset
                                errorMessage = nil
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: preset.symbol)
                                        .frame(width: 24)
                                    Text(preset.title)
                                    Spacer(minLength: 0)
                                    if selectedPreset == preset {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .glassSelectionAction(selected: selectedPreset == preset)
                            .disabled(isSending)
                        }
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Button {
                    Task { await sendSelectedPreset() }
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("알림 보내기")
                            .frame(maxWidth: .infinity)
                    }
                }
                .glassPrimaryAction()
                .disabled(selectedPreset == nil || isSending)
            }
            .padding(20)
            .background(GlassBackdrop())
            .navigationTitle("빠른 알림")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .disabled(isSending)
                }
            }
        }
        .interactiveDismissDisabled(isSending)
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func sendSelectedPreset() async {
        guard let selectedPreset, !isSending else { return }
        isSending = true
        errorMessage = nil
        do {
            try await MeetingNotificationSender.send(
                meetingID: meetingID,
                recipientID: recipient.id,
                preset: selectedPreset
            )
            onSent("\(recipient.name)님에게 ‘\(selectedPreset.shortTitle)’ 알림을 보냈어요.")
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }
}

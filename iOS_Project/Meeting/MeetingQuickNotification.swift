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

}

struct MeetingNotificationRecipient: Identifiable {
    let id: String
    let name: String
}

/// Drawing and hit testing share one layout captured when the hold begins.
/// Only the action buttons may move; the member's center is never clamped.
struct MeetingQuickMenuLayout {
    enum Arrangement { case radial, inwardRight, inwardLeft }

    static let buttonSize = CGSize(width: 84, height: 54)
    static let buttonCornerRadius: CGFloat = 16
    static let memberSize = CGSize(width: 82, height: 62)
    private static let preferredGap: CGFloat = 8

    let memberCenter: CGPoint
    let arrangement: Arrangement
    private let frames: [MeetingNotificationPreset: CGRect]

    init(anchor: CGRect, availableBounds: CGRect) {
        let center = CGPoint(x: anchor.midX, y: anchor.midY)
        memberCenter = center
        let halfWidth = Self.buttonSize.width / 2
        let halfHeight = Self.buttonSize.height / 2
        // Equal center distances leave a much larger vertical gap between these
        // wide cards. Keep the edge gap fixed; resolve screen collisions below.
        let horizontalSpacing = Self.memberSize.width / 2 + halfWidth + Self.preferredGap
        let verticalSpacing = Self.memberSize.height / 2 + halfHeight + Self.preferredGap
        let minimumX = availableBounds.minX + halfWidth
        let maximumX = availableBounds.maxX - halfWidth
        let nearX = min(max(center.x, minimumX), maximumX)
        let overflowsLeft = center.x - horizontalSpacing - halfWidth < availableBounds.minX
        let overflowsRight = center.x + horizontalSpacing + halfWidth > availableBounds.maxX
        let arrangement: Arrangement
        let centers: [MeetingNotificationPreset: CGPoint]

        if overflowsLeft || overflowsRight {
            let opensRight = overflowsLeft && (!overflowsRight || center.x <= availableBounds.midX)
            arrangement = opensRight ? .inwardRight : .inwardLeft
            let farX = nearX + (opensRight ? horizontalSpacing : -horizontalSpacing)
            centers = [
                .startingSoon: CGPoint(x: nearX, y: center.y - verticalSpacing),
                .almostThere: CGPoint(x: farX, y: center.y - verticalSpacing / 2),
                .whereAreYou: CGPoint(x: farX, y: center.y + verticalSpacing / 2),
                .runningLate: CGPoint(x: nearX, y: center.y + verticalSpacing)
            ]
        } else {
            arrangement = .radial
            centers = [
                .startingSoon: CGPoint(x: center.x, y: center.y - verticalSpacing),
                .almostThere: CGPoint(x: center.x + horizontalSpacing, y: center.y),
                .whereAreYou: CGPoint(x: center.x - horizontalSpacing, y: center.y),
                .runningLate: CGPoint(x: center.x, y: center.y + verticalSpacing)
            ]
        }

        self.arrangement = arrangement
        let preferredFrames = centers.mapValues { point in
            CGRect(x: point.x - halfWidth, y: point.y - halfHeight,
                   width: Self.buttonSize.width, height: Self.buttonSize.height)
        }
        var obstacles = [CGRect(x: center.x - Self.memberSize.width / 2,
                                y: center.y - Self.memberSize.height / 2,
                                width: Self.memberSize.width, height: Self.memberSize.height)]
        var resolvedFrames: [MeetingNotificationPreset: CGRect] = [:]

        // Reserve every action that already fits before moving any constrained
        // action. This preserves the fan instead of replacing it with a grid.
        for preset in MeetingNotificationPreset.allCases {
            let preferred = preferredFrames[preset]!
            if Self.canPlace(preferred, inside: availableBounds, avoiding: obstacles) {
                resolvedFrames[preset] = preferred
                obstacles.append(preferred)
            }
        }
        for preset in MeetingNotificationPreset.allCases where resolvedFrames[preset] == nil {
            let preferred = preferredFrames[preset]!
            let resolved = Self.nearestAvailableFrame(to: preferred, inside: availableBounds, avoiding: obstacles)
            resolvedFrames[preset] = resolved
            obstacles.append(resolved)
        }
        frames = resolvedFrames
    }

    private static let minimumGap: CGFloat = 6

    private static func canPlace(_ frame: CGRect, inside bounds: CGRect, avoiding obstacles: [CGRect]) -> Bool {
        bounds.contains(frame) && obstacles.allSatisfy { obstacle in
            frame.maxX + minimumGap <= obstacle.minX || frame.minX >= obstacle.maxX + minimumGap ||
            frame.maxY + minimumGap <= obstacle.minY || frame.minY >= obstacle.maxY + minimumGap
        }
    }

    private static func nearestAvailableFrame(to preferred: CGRect, inside bounds: CGRect, avoiding obstacles: [CGRect]) -> CGRect {
        // The closest free position lies on a screen or obstacle boundary.
        // Consider these positions only for the button that does not fit.
        let xs = [preferred.minX, bounds.minX, bounds.maxX - buttonSize.width] + obstacles.flatMap {
            [$0.minX - minimumGap - buttonSize.width, $0.maxX + minimumGap]
        }
        let ys = [preferred.minY, bounds.minY, bounds.maxY - buttonSize.height] + obstacles.flatMap {
            [$0.minY - minimumGap - buttonSize.height, $0.maxY + minimumGap]
        }
        var bestFrame = preferred
        var bestDistance = CGFloat.infinity
        for x in xs {
            for y in ys {
                let candidate = CGRect(origin: CGPoint(x: x, y: y), size: buttonSize)
                guard canPlace(candidate, inside: bounds, avoiding: obstacles) else { continue }
                let dx = x - preferred.minX
                let dy = y - preferred.minY
                let distance = dx * dx + dy * dy
                if distance < bestDistance {
                    bestFrame = candidate
                    bestDistance = distance
                }
            }
        }
        return bestFrame
    }

    func frame(for preset: MeetingNotificationPreset) -> CGRect { frames[preset]! }

    func preset(at point: CGPoint) -> MeetingNotificationPreset? {
        MeetingNotificationPreset.allCases.first { preset in
            let path = CGPath(roundedRect: frame(for: preset),
                              cornerWidth: Self.buttonCornerRadius, cornerHeight: Self.buttonCornerRadius,
                              transform: nil)
            return path.contains(point)
        }
    }
}

struct MeetingQuickNotificationMenu: View {
    let recipientName: String
    let highlightedPreset: MeetingNotificationPreset?
    let layout: MeetingQuickMenuLayout

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
                .frame(width: MeetingQuickMenuLayout.buttonSize.width, height: MeetingQuickMenuLayout.buttonSize.height)
                .background {
                    if highlightedPreset == preset {
                        RoundedRectangle(cornerRadius: MeetingQuickMenuLayout.buttonCornerRadius, style: .circular)
                            .fill(GlassTheme.blue)
                    } else {
                        RoundedRectangle(cornerRadius: MeetingQuickMenuLayout.buttonCornerRadius, style: .circular)
                            .fill(.regularMaterial)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: MeetingQuickMenuLayout.buttonCornerRadius, style: .circular)
                        .strokeBorder(.white.opacity(0.65), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
                .position(x: layout.frame(for: preset).midX, y: layout.frame(for: preset).midY)
            }

            VStack(spacing: 3) {
                Image(systemName: "bell.badge")
                    .font(.headline)
                Text(recipientName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(width: MeetingQuickMenuLayout.memberSize.width, height: MeetingQuickMenuLayout.memberSize.height)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(.white.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
            .position(layout.memberCenter)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }
}

/// Presents the dimming layer above the tab and navigation controllers while
/// leaving the original long-press recognizer in control of the drag.
@MainActor
final class MeetingQuickOverlayPresenter {
    static let shared = MeetingQuickOverlayPresenter()

    private var host: UIHostingController<MeetingQuickFullScreenOverlay>?
    private var layout: MeetingQuickMenuLayout?
    private weak var coordinateView: UIView?
    private weak var sourceWindow: UIWindow?
    private var presentedBounds: CGRect = .zero
    private var recipientName = ""
    private var instructionTop: CGFloat = 0

    private init() {}

    func present(in window: UIWindow, anchor: CGRect, recipientName: String) {
        dismiss()
        guard let root = window.rootViewController else { return }

        let bounds = root.view.bounds
        let localAnchor = root.view.convert(anchor, from: window)
            .offsetBy(dx: -bounds.minX, dy: -bounds.minY)
        let safeBounds = root.view.convert(window.bounds.inset(by: window.safeAreaInsets), from: window)
            .offsetBy(dx: -bounds.minX, dy: -bounds.minY)
            .insetBy(dx: 12, dy: 12)
        layout = MeetingQuickMenuLayout(anchor: localAnchor, availableBounds: safeBounds)
        coordinateView = root.view
        sourceWindow = window
        presentedBounds = bounds
        self.recipientName = recipientName
        instructionTop = window.safeAreaInsets.top + 54

        guard let overlay = overlay(highlightedPreset: nil) else { return }
        let host = UIHostingController(rootView: overlay)
        host.safeAreaRegions = []
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
        if let overlay = overlay(highlightedPreset: highlightedPreset) { host?.rootView = overlay }
    }

    func preset(at pointInWindow: CGPoint) -> MeetingNotificationPreset? {
        guard let coordinateView, let sourceWindow, coordinateView.bounds == presentedBounds else {
            dismiss()
            return nil
        }
        let point = coordinateView.convert(pointInWindow, from: sourceWindow)
        return layout?.preset(at: CGPoint(x: point.x - presentedBounds.minX, y: point.y - presentedBounds.minY))
    }

    func dismiss() {
        layout = nil
        coordinateView = nil
        sourceWindow = nil
        guard let host else { return }
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
        self.host = nil
    }

    private func overlay(highlightedPreset: MeetingNotificationPreset?) -> MeetingQuickFullScreenOverlay? {
        guard let layout else { return nil }
        return MeetingQuickFullScreenOverlay(
            layout: layout,
            recipientName: recipientName,
            highlightedPreset: highlightedPreset,
            instructionTop: instructionTop
        )
    }
}

private struct MeetingQuickFullScreenOverlay: View {
    let layout: MeetingQuickMenuLayout
    let recipientName: String
    let highlightedPreset: MeetingNotificationPreset?
    let instructionTop: CGFloat

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.28)

                MeetingQuickNotificationMenu(
                    recipientName: recipientName,
                    highlightedPreset: highlightedPreset,
                    layout: layout
                )

                VStack {
                    Text("버튼 위에서 손을 떼면 전송 · 버튼 밖은 취소")
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

//
//  MainTabView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import UserNotifications
import Combine

struct MainTabView: View {
    @State private var hiddenTabIndices: Set<Int> = []
    @StateObject private var chatStore = MeetingChatStore()
    @StateObject private var badgeCoordinator = AppBadgeCoordinator()
    @EnvironmentObject var loginViewModel: LoginViewModel
    @EnvironmentObject var router: AppRouter

    var body: some View {
        CustomTabView(hiddenTabIndices: $hiddenTabIndices)
            .environmentObject(chatStore)
            // Each tab's hosting controller handles its own keyboard. Resizing this
            // outer UIKit container as well would apply keyboard avoidance twice.
            .ignoresSafeArea()
            .background(GlassBackdrop())
            .onAppear {
                guard !ChatKeyboardUITest.isEnabled else { return }
                hiddenTabIndices = []
                checkUserValidity()  // 사용자 유효성 검사 호출
                PushTokenManager.syncCurrentToken()
                badgeCoordinator.start(uid: Auth.auth().currentUser?.uid)
                chatStore.start()
            }
            .onReceive(chatStore.$rooms.combineLatest(chatStore.$isLoading, chatStore.$errorMessage)) { rooms, loading, error in
                guard !loading, error == nil else { return }
                let unread = rooms.reduce(0) { $0 + $1.unreadCount }
                badgeCoordinator.updateChatCount(unread, uid: Auth.auth().currentUser?.uid)
            }
            .onDisappear {
                chatStore.stop()
                badgeCoordinator.stop(clearBadge: Auth.auth().currentUser == nil)
            }
    }

    private func checkUserValidity() {
        guard let currentUser = Auth.auth().currentUser else {
            print("Firebase 계정이 존재하지 않습니다. 로그아웃 처리합니다.")
            loginViewModel.signOut()
            return
        }

        currentUser.reload { error in
            if let error = error {
                print("사용자 정보 갱신 실패: \(error.localizedDescription)")
                loginViewModel.signOut()
            } else {
                print("사용자 정보 갱신 성공")
                let uid = currentUser.uid
                let db = Firestore.firestore()
                db.collection("users").document(uid).getDocument { snapshot, _ in
                    if let document = snapshot, document.exists {
                        print("회원가입 완료된 사용자입니다.")
                    } else {
                        print("회원가입 미완료 사용자입니다. 로그아웃 처리합니다.")
                        loginViewModel.signOut()
                    }
                }
            }
        }
    }
}

@MainActor
private final class AppBadgeCoordinator: ObservableObject {
    private let db = Firestore.firestore()
    private var currentUID: String?
    private var friendRequests: Int?
    private var meetingRequests: Int?
    private var unreadChats: Int?
    private var friendListener: ListenerRegistration?
    private var meetingListener: ListenerRegistration?
    private var queuedCount: Int?
    private var lastRequestedCount: Int?
    private var isApplyingBadge = false

    func start(uid: String?) {
        guard let uid else { stop(); return }
        guard currentUID != uid else { return }
        stop(clearBadge: false)
        currentUID = uid

        friendListener = db.collection("friendRequests")
            .whereField("toUserID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.currentUID == uid else { return }
                    if let error {
                        print("친구 요청 뱃지 조회 실패: \(error.localizedDescription)")
                        return
                    }
                    self.friendRequests = snapshot?.documents.count ?? 0
                    self.publishBadge()
                }
            }

        meetingListener = db.collection("meetingRequests")
            .whereField("toUserID", isEqualTo: uid)
            .whereField("status", isEqualTo: "pending")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self, self.currentUID == uid else { return }
                    if let error {
                        print("모임 요청 뱃지 조회 실패: \(error.localizedDescription)")
                        return
                    }
                    self.meetingRequests = snapshot?.documents.count ?? 0
                    self.publishBadge()
                }
            }
    }

    func updateChatCount(_ count: Int, uid: String?) {
        guard currentUID == uid, uid != nil else { return }
        unreadChats = max(0, count)
        publishBadge()
    }

    func stop(clearBadge: Bool = true) {
        friendListener?.remove()
        meetingListener?.remove()
        friendListener = nil
        meetingListener = nil
        currentUID = nil
        friendRequests = nil
        meetingRequests = nil
        unreadChats = nil
        lastRequestedCount = nil
        if clearBadge { queueBadge(0) }
    }

    private func publishBadge() {
        guard let friendRequests, let meetingRequests, let unreadChats else { return }
        let total = friendRequests + meetingRequests + unreadChats
        guard lastRequestedCount != total else { return }
        lastRequestedCount = total
        queueBadge(total)
    }

    private func queueBadge(_ count: Int) {
        queuedCount = count
        guard !isApplyingBadge else { return }
        isApplyingBadge = true
        Task { await applyQueuedBadges() }
    }

    private func applyQueuedBadges() async {
        while let count = queuedCount {
            queuedCount = nil
            do {
                try await UNUserNotificationCenter.current().setBadgeCount(count)
            } catch {
                print("앱 아이콘 뱃지 갱신 실패: \(error.localizedDescription)")
            }
        }
        isApplyingBadge = false
    }
}

struct CustomTabView: UIViewControllerRepresentable {
    @Binding var hiddenTabIndices: Set<Int>
    @EnvironmentObject var router: AppRouter
    @EnvironmentObject var loginViewModel: LoginViewModel
    @EnvironmentObject var chatStore: MeetingChatStore

    // Keep router in sync when user taps tabs
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITabBarControllerDelegate {
        var parent: CustomTabView
        init(_ parent: CustomTabView) { self.parent = parent }
        func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
            if let index = tabBarController.viewControllers?.firstIndex(of: viewController) {
                DispatchQueue.main.async {
                    self.parent.router.selectedTabIndex = index
                }
            }
        }
    }

    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()
        tabBarController.delegate = context.coordinator

        tabBarController.tabBar.tintColor = UIColor(GlassTheme.blue)

#if DEBUG
        if ChatKeyboardUITest.isEnabled {
            tabBarController.viewControllers = [AppTabIndex.meeting, .chat].map { tab in
                let host = UIHostingController(rootView: ChatKeyboardUITest.Entry(isTabBarHidden: visibilityBinding(for: tab), viaDetail: tab == .meeting))
                host.tabBarItem = UITabBarItem(title: tab == .meeting ? "모임" : "채팅", image: UIImage(systemName: "bubble.left"), tag: tab.rawValue)
                return host
            }
            return tabBarController
        }
#endif

        // iOS 26 미만: 탭바 투명 고정 및 glassBarBackdrop()로 배경 지정
        if #unavailable(iOS 26.0) {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.shadowColor = .clear
            tabBarController.tabBar.standardAppearance = appearance
            tabBarController.tabBar.scrollEdgeAppearance = appearance
        }

        let meetingListView = UIHostingController(
            rootView: MeetingListView(isTabBarHidden: visibilityBinding(for: .meeting))
                .environmentObject(router)
                .environmentObject(chatStore)
        )
        meetingListView.tabBarItem = UITabBarItem(title: "모임", image: UIImage(systemName: "list.bullet"), tag: 0)

        let chatView = UIHostingController(
            rootView: MeetingChatListView(isTabBarHidden: visibilityBinding(for: .chat))
                .environmentObject(chatStore)
                .environmentObject(router)
        )
        chatView.tabBarItem = UITabBarItem(title: "채팅", image: UIImage(systemName: "bubble.left.and.bubble.right"), tag: 1)

        let friendView = UIHostingController(
            rootView: FriendListView(isTabBarHidden: visibilityBinding(for: .friend))
                .environmentObject(router)
        )
        friendView.tabBarItem = UITabBarItem(title: "친구", image: UIImage(systemName: "person.3"), tag: 2)

        let profileView = UIHostingController(
            rootView: ProfileView(isTabBarHidden: visibilityBinding(for: .profile))
                .environmentObject(router)
                .environmentObject(loginViewModel)
        )
        profileView.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gear"), tag: 3)

        tabBarController.viewControllers = [meetingListView, chatView, friendView, profileView]
        tabBarController.selectedIndex = router.selectedTabIndex
        return tabBarController
    }

    func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {
        context.coordinator.parent = self
        let unread = chatStore.totalUnreadCount
        uiViewController.viewControllers?[AppTabIndex.chat.rawValue].tabBarItem.badgeValue =
            unread > 0 ? ChatCountLabel.text(unread) : nil
        if uiViewController.selectedIndex != router.selectedTabIndex {
            uiViewController.selectedIndex = router.selectedTabIndex
        }
        let shouldHideTabBar = hiddenTabIndices.contains(uiViewController.selectedIndex)
        if #available(iOS 18.0, *) {
            if uiViewController.isTabBarHidden != shouldHideTabBar {
                uiViewController.setTabBarHidden(shouldHideTabBar, animated: false)
            }
        } else if uiViewController.tabBar.isHidden != shouldHideTabBar {
            uiViewController.tabBar.isHidden = shouldHideTabBar
        }
    }

    private func visibilityBinding(for tab: AppTabIndex) -> Binding<Bool> {
        Binding(
            get: { hiddenTabIndices.contains(tab.rawValue) },
            set: { isHidden in
                if isHidden {
                    hiddenTabIndices.insert(tab.rawValue)
                } else {
                    hiddenTabIndices.remove(tab.rawValue)
                }
            }
        )
    }
}

// Translucent surfaces share the same treatment without changing a screen's layout.
enum GlassTheme {
    static let blue = Color(red: 0.18, green: 0.43, blue: 0.94)
    static let cyan = Color(red: 0.13, green: 0.78, blue: 0.84)
}

struct GlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.06, green: 0.13, blue: 0.24), Color(red: 0.04, green: 0.20, blue: 0.25)]
                        : [Color(red: 0.85, green: 0.93, blue: 1.0), Color(red: 0.87, green: 0.98, blue: 0.97)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(GlassTheme.cyan.opacity(colorScheme == .dark ? 0.28 : 0.42))
                    .frame(width: 280, height: 280)
                    .blur(radius: 50)
                    .position(x: geometry.size.width * 0.9, y: 80)

                Circle()
                    .fill(GlassTheme.blue.opacity(colorScheme == .dark ? 0.25 : 0.27))
                    .frame(width: 320, height: 320)
                    .blur(radius: 60)
                    .position(x: geometry.size.width * 0.1, y: geometry.size.height * 0.85)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

// 페이지 배경과 동일한 GlassBackdrop 상단·하단 바 영역에 지정
struct GlassBarBackdrop: View {
    var fade: CGFloat = 12

    var body: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            GlassBackdrop()
                .mask {
                    VStack(spacing: 0) {
                        Rectangle().frame(height: insets.top)
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: fade)
                        Spacer(minLength: 0)
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: fade)
                        Rectangle().frame(height: insets.bottom)
                    }
                    .ignoresSafeArea()
                }
                .ignoresSafeArea()
        }
        .ignoresSafeArea(.keyboard)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct GlassPanel: View {
    @Environment(\.colorScheme) private var colorScheme
    var radius: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        shape
            .fill(Color.white.opacity(colorScheme == .dark ? 0.06 : 0.12))
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.35 : 0.55),
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.20)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: GlassTheme.blue.opacity(colorScheme == .dark ? 0.12 : 0.08), radius: 12, y: 5)
    }
}

struct ClearGlassButtonStyle: ButtonStyle {
    var isPrimary = false

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .foregroundStyle(isPrimary ? GlassTheme.blue : Color.primary)
            .fontWeight(isPrimary ? .semibold : .regular)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.65 : 1)

        if #available(iOS 26.0, *) {
            // Button already owns the touch interaction; glass only draws the surface.
            label.glassEffect(.clear, in: .rect(cornerRadius: 16))
        } else {
            label.background(GlassPanel(radius: 16))
        }
    }
}

struct ClearGlassCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Circle())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

extension View {
    @ViewBuilder
    func glassSurface(radius: CGFloat = 18) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.clear, in: .rect(cornerRadius: radius))
        } else {
            background(GlassPanel(radius: radius))
        }
    }

    func glassPrimaryAction() -> some View {
        buttonStyle(ClearGlassButtonStyle(isPrimary: true))
    }

    func glassSecondaryAction() -> some View {
        buttonStyle(ClearGlassButtonStyle())
    }

    @ViewBuilder
    func glassSelectionAction(selected: Bool) -> some View {
        if selected {
            glassPrimaryAction()
        } else {
            glassSecondaryAction()
        }
    }

    // iOS 26 미만: 투명 네비게이션 바·탭바 배경 지정
    // iOS 26 이상: 시스템 Liquid Glass
    @ViewBuilder
    func glassBarBackdrop() -> some View {
        if #available(iOS 26.0, *) {
            self
        } else {
            overlay { GlassBarBackdrop() }
        }
    }

    @ViewBuilder
    func glassSubtleCircle() -> some View {
        if #available(iOS 26.0, *) {
            contentShape(Circle())
                .glassEffect(.clear, in: Circle())
        } else {
            background(Color.white.opacity(0.12), in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.6), lineWidth: 1))
        }
    }
}

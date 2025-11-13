//
//  MainTabView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct MainTabView: View {
    @State private var isTabBarHidden = false
    @EnvironmentObject var loginViewModel: LoginViewModel
    @EnvironmentObject var router: AppRouter

    var body: some View {
        CustomTabView(isTabBarHidden: $isTabBarHidden)
            .onAppear {
                isTabBarHidden = false
                checkUserValidity()  // 사용자 유효성 검사 호출
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

struct CustomTabView: UIViewControllerRepresentable {
    @Binding var isTabBarHidden: Bool
    @EnvironmentObject var router: AppRouter

    // Keep router in sync when user taps tabs
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    class Coordinator: NSObject, UITabBarControllerDelegate {
        let parent: CustomTabView
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

        let meetingListView = UIHostingController(
            rootView: MeetingListView(isTabBarHidden: $isTabBarHidden)
                .environmentObject(router)
        )
        meetingListView.tabBarItem = UITabBarItem(title: "모임", image: UIImage(systemName: "list.bullet"), tag: 0)

        let friendView = UIHostingController(
            rootView: FriendListView(isTabBarHidden: $isTabBarHidden)
                .environmentObject(router)
        )
        friendView.tabBarItem = UITabBarItem(title: "친구", image: UIImage(systemName: "person.3"), tag: 1)

        let profileView = UIHostingController(
            rootView: ProfileView(isTabBarHidden: $isTabBarHidden)
                .environmentObject(router)
        )
        profileView.tabBarItem = UITabBarItem(title: "설정", image: UIImage(systemName: "gear"), tag: 2)

        tabBarController.viewControllers = [meetingListView, friendView, profileView]
        tabBarController.selectedIndex = router.selectedTabIndex
        return tabBarController
    }

    func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {
        if uiViewController.selectedIndex != router.selectedTabIndex {
            uiViewController.selectedIndex = router.selectedTabIndex
        }
        uiViewController.tabBar.isHidden = isTabBarHidden
    }
}

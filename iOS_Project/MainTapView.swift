//
//  TapView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import NMapsMap

import SwiftUI

struct MainTabView: View {
    @State private var isTabBarHidden = false
    
    var body: some View {
        CustomTabView(isTabBarHidden: $isTabBarHidden)
            .onAppear {
                isTabBarHidden = false
            }
    }
}

struct CustomTabView: UIViewControllerRepresentable {
    @Binding var isTabBarHidden: Bool
    
    func makeUIViewController(context: Context) -> UITabBarController {
        let tabBarController = UITabBarController()
        
        let meetingListView = UIHostingController(rootView: MeetingListView(isTabBarHidden: $isTabBarHidden))
        meetingListView.tabBarItem = UITabBarItem(title: "모임", image: UIImage(systemName: "list.bullet"), tag: 0)
        
        let friendView = UIHostingController(rootView: FriendListView(isTabBarHidden: $isTabBarHidden))
        friendView.tabBarItem = UITabBarItem(title: "친구", image: UIImage(systemName: "person.3"), tag: 1)
        
        let profileView = UIHostingController(rootView: ProfileView(isTabBarHidden: $isTabBarHidden))
        profileView.tabBarItem = UITabBarItem(title: "내정보", image: UIImage(systemName: "person"), tag: 2)
        
        tabBarController.viewControllers = [meetingListView, friendView, profileView]
        
        return tabBarController
    }
    
    func updateUIViewController(_ uiViewController: UITabBarController, context: Context) {
        uiViewController.tabBar.isHidden = isTabBarHidden
    }
}

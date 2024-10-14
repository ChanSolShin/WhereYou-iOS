//
//  TapView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            MeetingListView() // 첫 번째 탭: 모임 리스트
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("모임")
                    }
            
            FriendView() // 두 번째 탭: 친구 목록
                .tabItem {
                    Image(systemName: "person.3")
                    Text("친구")
                }
            
            ProfileView() // 세 번째 탭: 내 프로필
                .tabItem {
                    Image(systemName: "person")
                    Text("내정보")
                }
        }
    }
}
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}

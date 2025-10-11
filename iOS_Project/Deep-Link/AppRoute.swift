//
//  AppRoute.swift
//  iOS_Project
//
//  Created by CHOI on 10/7/25.
//


import Foundation

/// 푸시 알림 등으로부터 진입할 목적지를 정의
enum DeepLinkDestination: Equatable {
    case friendRequests
    case meetingRequests
    case meeting(id: String)
}

/// 각 탭 인덱스 정의 (MainTabView에서 사용)
enum AppTabIndex: Int {
    case meeting = 0
    case friend = 1
    case profile = 2
}

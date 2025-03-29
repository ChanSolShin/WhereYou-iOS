//
//  AddFriendType.swift
//  iOS_Project
//
//  Created by 신찬솔 on 3/23/25.
//


import Foundation

enum AddFriendType: Identifiable {
    case email, phone
    var id: Int {
        switch self {
        case .email: return 0
        case .phone: return 1
        }
    }
}

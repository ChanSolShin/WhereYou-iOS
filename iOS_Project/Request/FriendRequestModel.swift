//
//  FriendRequestModel..swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/29/24.
//

import Foundation

struct FriendRequestModel: Identifiable {
    var id: String
    var fromUserID: String
    var fromUserName: String
    var toUserID: String
    var status: String
}

//
//  MeetingRequestModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/31/24.
//

import Foundation

struct MeetingRequestModel: Identifiable {
    var id: String
    var fromUserID: String
    var fromUserName: String
    var toUserID: String
    var meetingName: String
    var status: String
    var meetingID: String
}

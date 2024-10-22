//
//  MeetinfListModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import Foundation

struct MeetingListModel: Identifiable {
    let id = UUID() // 고유 ID
    var title: String // 모임 제목
    var date: Date // 모임 날짜, 시간
   // var Name: String // 모임 이름
}

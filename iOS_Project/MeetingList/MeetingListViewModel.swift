//
//  MeetingListViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import Foundation

// 테스트용 코드. if you want test, Comment this code
class MeetingListViewModel: ObservableObject {
    @Published var meetings: [MeetingListModel] = [ // Firebase에서 meeting의 정보를 가져와야함.
        MeetingListModel(title: "술", date: createDate(year: 2024, month: 10, day: 13, hour: 18, minute: 0) ?? Date()),
//        MeetingListModel(title: "에니악모임", date: createDate(year: 2024, month: 10, day: 14, hour: 12, minute: 30) ?? Date()),
//        MeetingListModel(title: "저녁 데이트", date: createDate(year: 2024, month: 10, day: 15, hour: 19, minute: 0) ?? Date()),
//        MeetingListModel(title: "술2", date: createDate(year: 2024, month: 10, day: 16, hour: 21, minute: 0) ?? Date()),
//        MeetingListModel(title: "회의", date: createDate(year: 2024, month: 10, day: 17, hour: 10, minute: 0) ?? Date()),
//        MeetingListModel(title: "팀 회의", date: createDate(year: 2024, month: 10, day: 18, hour: 9, minute: 30) ?? Date()),
//        MeetingListModel(title: "프로젝트 발표", date: createDate(year: 2024, month: 10, day: 19, hour: 14, minute: 0) ?? Date()),
//        MeetingListModel(title: "점심 약속", date: createDate(year: 2024, month: 10, day: 20, hour: 12, minute: 0) ?? Date()),
//        MeetingListModel(title: "술3", date: createDate(year: 2024, month: 10, day: 21, hour: 20, minute: 0) ?? Date()),
//        MeetingListModel(title: "에니악 회식", date: createDate(year: 2024, month: 10, day: 22, hour: 18, minute: 30) ?? Date())
    ]
    
    
    static func createDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.year = year
        dateComponents.month = month
        dateComponents.day = day
        dateComponents.hour = hour
        dateComponents.minute = minute
        return Calendar.current.date(from: dateComponents)
    }
}

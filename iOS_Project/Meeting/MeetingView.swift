//
//  MeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import NMapsMap

struct MeetingView: View {
    var meeting: MeetingListModel // 임시코드. Firebase에서 meeting의 정보를 가져와야함.

    var body: some View {
        VStack {
          
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

struct MeetingView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingView(meeting: MeetingListModel(title: "Sample Meeting", date: Date()))
    }
}

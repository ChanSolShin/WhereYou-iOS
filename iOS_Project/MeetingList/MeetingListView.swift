//
//  MeetingListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI


struct MeetingListView: View {
    @StateObject private var viewModel = MeetingListViewModel() // ViewModel 인스턴스 생성
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("모임")
                        .font(.largeTitle)
                        .padding()
                        .foregroundColor(.black)
                    Spacer()
                }
                Spacer()
                
                List(viewModel.meetings) { meeting in
                    HStack {
                        NavigationLink(destination: MeetingView(meeting: meeting)) {
                            Text(meeting.title)
                                .font(.headline)
                                .padding()
                        }
                        Spacer()
                        Text("\(meeting.date, formatter: dateFormatter)") // 오른쪽에 날짜 표시
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                NavigationLink(destination: AddMeetingView()) {
                    Text("모임추가")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 60)
                        .background(Color.blue)
                        .cornerRadius(30)
                        .padding(.bottom, 30)
                        .padding(.top, 30)
                }
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct MeetingListView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingListView()
    }
}

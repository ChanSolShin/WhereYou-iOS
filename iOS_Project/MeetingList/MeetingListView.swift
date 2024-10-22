//
//  MeetingListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import NMapsMap

struct MeetingListView: View {
    @StateObject private var meetingViewModel = MeetingViewModel() // MeetingViewModel 인스턴스 생성
    @StateObject private var viewModel: MeetingListViewModel
    
    @State private var searchText = ""
    @State private var isSearching = false
    
    init() {
        let meetingViewModel = MeetingViewModel()
        _viewModel = StateObject(wrappedValue: MeetingListViewModel(meetingViewModel: meetingViewModel))
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack {
                    HStack {
                        Text("모임")
                            .font(.largeTitle)
                            .foregroundColor(.black)
                            .padding()
                            .padding(.top, 15)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isSearching.toggle()
                            }
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                        }
                        .padding(.trailing)
                        .padding(.top, 15)
                    }
                    if isSearching {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .padding(.leading, 10)
                            TextField("검색어를 입력하세요", text: $searchText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 300)
                            Button(action: {
                                searchText = ""
                                withAnimation {
                                    isSearching.toggle()
                                }
                            }) {
                                Text("취소")
                                    .font(.headline)
                            }
                        }
                    }
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(viewModel.meetings.filter { meeting in
                                searchText.isEmpty || meeting.title.localizedCaseInsensitiveContains(searchText)
                            }) { meeting in
                                NavigationLink(destination: MeetingView(meeting: meeting)) {
                                    HStack {
                                        Text(meeting.title)
                                            .font(.headline)
                                            .padding()
                                            .foregroundColor(.black)
                                        Spacer()
                                        VStack(alignment: .trailing) {
                                            Text("\(meeting.date, formatter: dateFormatter)")
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Text(meeting.meetingAddress)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        .padding()
                                    }
                                }
                                .onTapGesture {
                                    if let index = viewModel.meetings.firstIndex(where: { $0.id == meeting.id }) {
                                        viewModel.selectMeeting(at: index) // 선택한 모임 정보를 MeetingViewModel에 전달
                                    }
                                }
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                NavigationLink(destination: AddMeetingView(viewModel: AddMeetingViewModel()), label: {
                    Text(" + 모임생성")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .background(Color.blue)
                        .cornerRadius(30)
                        .padding()
                })
            }
        }
    }
}

struct MeetingListView_Previews: PreviewProvider {
    static var previews: some View {
        MeetingListView()
    }
}

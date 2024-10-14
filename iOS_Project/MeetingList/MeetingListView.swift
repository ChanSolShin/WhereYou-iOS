//
//  MeetingListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingListViewModel() // ViewModel 인스턴스 생성
    @State private var searchText = "" // 검색 텍스트
    @State private var isSearching = false // 검색 상태
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                
                VStack {
                    HStack {
                        Text("모임")
                            .font(.largeTitle)
                            .foregroundColor(.black)
                            .padding()
                        Spacer()
                        // 돋보기 버튼 추가
                        Button(action: {
                            withAnimation {
                                isSearching.toggle()
                            }
                        }) {
                            
                            Image(systemName: "magnifyingglass")
                                .font(.title)
                        }
                        .padding(.trailing)
                    }
                    // 검색 상태에 따라 텍스트 필드 표시
                    if isSearching {
                        HStack{
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
                                searchText.isEmpty || meeting.title.localizedCaseInsensitiveContains(searchText) // 검색 필터링
                            }) { meeting in
                                NavigationLink(destination: MeetingView(meeting: meeting)) {
                                    HStack {
                                        Text(meeting.title)
                                            .font(.headline)
                                            .padding()
                                            .foregroundColor(.black)
                                        Spacer()
                                        Text("\(meeting.date, formatter: dateFormatter)") // 오른쪽에 날짜 표시
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                    .padding()
                                }
                                Divider()
                            }
                        }
                        .padding(.horizontal)                    }
                }
                // 모임생성 버튼
                NavigationLink(destination: AddMeetingView()) {
                    Text(" + 모임생성")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 150, height: 50)
                        .background(Color.blue)
                        .cornerRadius(30)
                        .padding()
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

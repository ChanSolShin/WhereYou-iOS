//
//  MeetingListView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import NMapsMap

struct MeetingListView: View {
    @StateObject private var viewModel = MeetingListViewModel(meetingViewModel: MeetingViewModel())
    // ViewModel 인스턴스 생성
    @State private var searchText = "" // 검색 텍스트
    @State private var isSearching = false // 검색 상태
    @Binding var isTabBarHidden: Bool
    
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                
                VStack {
                    HStack {
                        Text("모임")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                            .padding()
                            .padding(.top,15)
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
                        .padding(.top,15)
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
                                NavigationLink(destination: MeetingView(meeting: meeting, meetingViewModel: MeetingViewModel())
                                    .onAppear(){isTabBarHidden = true}
                                    .onDisappear(){isTabBarHidden = false}) {
                                        HStack {
                                            Text(meeting.title)
                                                .font(.headline)
                                                .padding()
                                                .foregroundColor(.black)
                                            Spacer()
                                            VStack(alignment: .trailing) { // 텍스트 정렬을 오른쪽으로 설정
                                                Text("\(meeting.date, formatter: dateFormatter)") // 오른쪽에 날짜 표시
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                                Text(meeting.meetingAddress) // 오른쪽에 모임 장소 표시
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                            .padding()
                                        }
                                        
                                    }
                                Divider()
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // 모임 생성 버튼
                NavigationLink(destination: AddMeetingView(viewModel: AddMeetingViewModel())
                    .onAppear { isTabBarHidden = true }
                    .onDisappear { isTabBarHidden = false }
                ) {
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                        .padding(.bottom, 20)
                        .padding(.trailing, 20)
                }
            }
        }
    }
}


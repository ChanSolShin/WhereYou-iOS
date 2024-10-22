//
//  AddMeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//

import SwiftUI
import CoreLocation
import NMapsMap
import Foundation

struct AddMeetingView: View {
    
    @ObservedObject var viewModel: AddMeetingViewModel
    @State private var showDatePicker = false
    @State private var showLocationModal = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView{
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                Text("모임 이름을 입력하세요")
                    .font(.title2)
                TextField("모임 이름", text: $viewModel.meeting.meetingName)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .frame(width: 350, height: 40)
                    .keyboardType(.default) // 키보드 타입 변경
                    .background(Color.gray.opacity(0.2))
                
                // 날짜 선택 버튼과 선택된 날짜 표시
                
                    Button(action: {
                        showDatePicker.toggle()
                    }) {
                        Text("날짜 선택")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .frame(width: 100, height: 50)
                    }
                    // 선택된 날짜를 텍스트로 표시
                HStack{
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text("\(viewModel.meeting.meetingDate, formatter: dateFormatter)")
                        .font(.headline)
                }
                
                
                // 장소 선택 버튼과 선택된 주소 표시
                Button(action: {
                    showLocationModal.toggle()
                }) {
                    Text("장소 선택")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .frame(width: 100, height: 50)
                }
                HStack{
                    Image(systemName: "map")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text(viewModel.meeting.meetingAddress ?? "선택된 장소 없음")
                        .font(.headline)
                }
                
                // 추가하기 버튼
                Button(action: {
                    viewModel.addMeeting() // 파이어베이스로 미팅 정보 전송
                    presentationMode.wrappedValue.dismiss()
                    // 디버그 출력
                    print("모임 이름: \(viewModel.meeting.meetingName)")
                    print("모임 날짜: \(viewModel.meeting.meetingDate)")
                    print("모임 주소: \(viewModel.meeting.meetingAddress ?? "주소 미지정")")
                    let location = viewModel.meeting.meetingLocation
                    print("모임 좌표: \(location.latitude), \(location.longitude)")
                }) {
                    Text("추가하기")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(30)
                        .frame(width: 150, height: 50)
                }
                .padding(.horizontal, 20)
                .padding(.top, 100)
            }
            .padding(.vertical, 20)
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    DatePicker("Select a date", selection: $viewModel.meeting.meetingDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .environment(\.locale, Locale(identifier: String(Locale.preferredLanguages[0])))
                        .padding()
                    
                    Button("완료") {
                        showDatePicker = false
                    }
                    .font(.headline)
                    .padding(.leading, 300)
                }
            }
            .sheet(isPresented: $showLocationModal) {
                AddLocationView(viewModel: viewModel)
            }
            
                    }
        .navigationTitle("모임추가")
        .font(.largeTitle)

    }
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        formatter.dateFormat = "YYYY년 M월 d일 a h:mm"
        return formatter
    }
}

struct AddMeetingView_Previews: PreviewProvider {
    static var previews: some View {
        AddMeetingView(viewModel: AddMeetingViewModel())
    }
}


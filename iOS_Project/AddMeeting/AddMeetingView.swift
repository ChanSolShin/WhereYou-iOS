//
//  AddMeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/13/24.
//

import SwiftUI
import CoreLocation




struct AddMeetingView: View {
    @StateObject private var viewModel = AddMeetingViewModel()
    @State private var showDatePicker = false // DatePicker 표시 여부
    
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("모임이름", text: $viewModel.meeting.meetingName)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 50)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.leading, 25)
                    .padding(.trailing, 25)
                    .font(.headline)
                
                HStack {
                    Button(action: {
                        showDatePicker.toggle() // 버튼을 눌렀을 때 모달을 띄움
                    }) {
                        Text("날짜 선택")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    // 선택된 날짜를 텍스트로 표시
                    Text("\(viewModel.meeting.meetingDate, formatter: dateFormatter)")
                        .font(.headline)
                }
                    
                }
            
            // Sheet를 통해 DatePicker 모달 띄우기
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    DatePicker(
                        "Select a date",
                        selection: $viewModel.meeting.meetingDate,
                        displayedComponents: [.date, .hourAndMinute] // 날짜와 시간 선택 가능
                    )
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .padding()
                    
                    Button("완료") {
                        showDatePicker = false // 날짜 선택 후 모달 닫기
                    }
                    .font(.headline)
                    .padding(.leading, 300)
                }
                
            }
            var dateFormatter: DateFormatter {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter
            }
        }
        .navigationTitle("모임일정 추가")
        .font(.largeTitle)
        
        
    }
}



struct AddMeetingView_Previews: PreviewProvider {
    static var previews: some View {
        AddMeetingView()
    }
}


//  EditMeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import SwiftUI
import CoreLocation
import NMapsMap

struct EditMeetingView: View {
    @StateObject private var viewModel = EditMeetingViewModel()
    @Environment(\.dismiss) var dismiss
    var meetingID: String
    @State private var showDatePicker = false
    @State private var showLocationModal = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                Text("모임 이름을 입력하세요")
                    .font(.title2)
                TextField("모임 이름", text: $viewModel.meetingName)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .frame(width: 350, height: 40)
                    .keyboardType(.default)
                    .background(Color.gray.opacity(0.2))
                
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
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text("\(viewModel.meetingDate, formatter: dateFormatter)")
                        .font(.headline)
                }
                
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
                    Text(viewModel.meetingAddress)
                        .font(.headline)
                }
                // 추가하기 버튼
                Button(action: {
                    // 햅틱 피드백 생성
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred() // 햅틱 반응 발생
                    
                    viewModel.updateMeetingData(meetingID: meetingID)
                    dismiss()
                    // 디버그 출력
                    print("모임 이름: \(viewModel.meetingName)")
                    print("모임 날짜: \(viewModel.meetingDate)")
                    print("모임 주소: \(viewModel.meetingAddress)")
                    let location = viewModel.meetingLocation
                    print("모임 좌표: \(location.latitude), \(location.longitude)")
                }) {
                    Text("수정하기")
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
            .sheet(isPresented: $showLocationModal) {
                EditLocationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    DatePicker("Select a date", selection: $viewModel.meetingDate, displayedComponents: [.date, .hourAndMinute])
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
            .onAppear {
                viewModel.fetchMeetingData(meetingID: meetingID)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("✕")
                            .font(.system(size: 25))
                            .foregroundColor(.blue)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("모임 정보 수정하기")
                        .font(.title3)
                        .bold()
                }
            }
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        formatter.dateFormat = "YYYY년 M월 d일 a h:mm"
        return formatter
    }
}

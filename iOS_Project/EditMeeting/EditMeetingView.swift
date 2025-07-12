
//  EditMeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import SwiftUI
import CoreLocation

struct EditMeetingView: View {
    @StateObject private var viewModel = EditMeetingViewModel()
    @Environment(\.dismiss) var dismiss
    var meetingID: String
    @State private var showDatePicker = false
    @State private var showLocationModal = false
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
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
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text(viewModel.meetingAddress)
                        .font(.headline)
                }
                
                Button(action: {
                    viewModel.updateMeetingData(meetingID: meetingID)
                    alertMessage = "모임 정보가 수정되었습니다!"
                    showAlert = true
                    
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
                Text("모임은 \(viewModel.meetingDate.addingTimeInterval(7200), formatter: dateFormatter)에 삭제됩니다")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            }
            .padding(.vertical, 20)
            .padding(.bottom, 100)
            .sheet(isPresented: $showLocationModal) {
                EditLocationView(viewModel: viewModel)
            }
            .sheet(isPresented: $showDatePicker) {
                VStack {
                    DatePicker("Select a date", selection: $viewModel.meetingDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
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
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("알림"),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("확인"), action: {
                        dismiss()
                    })
                )
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

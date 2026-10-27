
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
    @State private var presentedSheet: MeetingFormSheet?
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                Spacer().frame(height: 20)
                Text("모임 이름을 입력하세요")
                    .font(.title2)
                TextField("모임 이름", text: $viewModel.meetingName)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .keyboardType(.default)
                    .glassSurface(radius: 10)
                    .padding(.horizontal, 24)
                
                Button(action: {
                    presentedSheet = .date
                }) {
                    Label("날짜 선택", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .glassSecondaryAction()
                .controlSize(.large)
                .padding(.horizontal, 24)
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text("\(viewModel.meetingDate, formatter: dateFormatter)")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                
                Button(action: {
                    presentedSheet = .location
                }) {
                    Label("장소 선택", systemImage: "map")
                        .frame(maxWidth: .infinity)
                }
                .glassSecondaryAction()
                .controlSize(.large)
                .padding(.horizontal, 24)
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text(viewModel.meetingAddress)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                
                Button(action: {
                    viewModel.updateMeetingData(meetingID: meetingID)
                    alertMessage = "모임 정보가 수정되었습니다!"
                    showAlert = true
                    
                }) {
                    Text("수정하기")
                        .frame(maxWidth: .infinity)
                }
                .glassPrimaryAction()
                .controlSize(.large)
                .padding(.horizontal, 24)
                Text("모임은 \(viewModel.meetingDate.addingTimeInterval(7200), formatter: dateFormatter)에 삭제됩니다")
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
                .padding(.vertical, 20)
                .padding(.bottom, 100)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .sheet(item: $presentedSheet) { sheet in
                switch sheet {
                case .date:
                    GlassDatePickerSheet(date: $viewModel.meetingDate)
                case .location:
                    EditLocationView(viewModel: viewModel)
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
            .background(GlassBackdrop())
        }
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        formatter.dateFormat = "yyyy년 M월 d일 a h:mm"
        return formatter
    }
}

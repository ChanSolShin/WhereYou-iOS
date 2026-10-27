//
//  AddMeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//

import SwiftUI
import CoreLocation
import Foundation

enum MeetingFormSheet: Hashable, Identifiable {
    case date
    case location

    var id: Self { self }
}

struct AddMeetingView: View {
    
    @ObservedObject var viewModel: AddMeetingViewModel
    @State private var presentedSheet: MeetingFormSheet?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 20)
                Text("모임 이름을 입력하세요")
                    .font(.title2)
                TextField("모임 이름", text: $viewModel.meeting.meetingName)
                    .font(.system(size: 16))
                    .autocapitalization(.none)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .keyboardType(.default) // 키보드 타입 변경
                    .glassSurface(radius: 10)
                    .padding(.horizontal, 24)
                
                // 날짜 선택 버튼과 선택된 날짜 표시
                Button(action: {
                    presentedSheet = .date
                }) {
                    Label("날짜 선택", systemImage: "calendar")
                        .frame(maxWidth: .infinity)
                }
                .glassSecondaryAction()
                .controlSize(.large)
                .padding(.horizontal, 24)
                
                // 선택된 날짜를 텍스트로 표시
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    Text("\(viewModel.meeting.meetingDate, formatter: dateFormatter)")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                
                // 장소 선택 버튼과 선택된 주소 표시
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
                    Text(viewModel.meeting.meetingAddress ?? "선택된 장소 없음")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 16)
                
                // 추가하기 버튼
                Button(action: {
                    // 햅틱 피드백 생성
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred() // 햅틱 반응 발생
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
                        .frame(maxWidth: .infinity)
                }
                .glassPrimaryAction()
                .controlSize(.large)
                .padding(.horizontal, 24)
                .disabled(viewModel.successAddMeeting)
                Text("모임은 \(viewModel.meeting.meetingDate.addingTimeInterval(7200), formatter: dateFormatter) 에 삭제됩니다")
                    .font(.footnote)
                    .foregroundColor(.red)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }
            .padding(.vertical, 20)
        }
        .scrollBounceBehavior(.basedOnSize)
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .date:
                GlassDatePickerSheet(date: $viewModel.meeting.meetingDate)
            case .location:
                AddLocationView(viewModel: viewModel)
            }
        }
        .background(GlassBackdrop())
        .navigationTitle("모임추가")
        
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(abbreviation: "KST")
        formatter.dateFormat = "yyyy년 M월 d일 a h:mm"
        return formatter
    }
}

struct GlassDatePickerSheet: View {
    @Binding var date: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                DatePicker("모임 날짜", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .tint(GlassTheme.blue)
                    .padding(16)
                    .glassSurface(radius: 20)
                    .padding(.horizontal, 20)

                Spacer(minLength: 0)

                Button { dismiss() } label: {
                    Text("완료").frame(maxWidth: .infinity)
                }
                    .glassPrimaryAction()
                    .controlSize(.large)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
            }
            .padding(.top, 20)
            .background(GlassBackdrop())
            .navigationTitle("날짜 선택")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.locale, Locale(identifier: "ko_KR"))
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

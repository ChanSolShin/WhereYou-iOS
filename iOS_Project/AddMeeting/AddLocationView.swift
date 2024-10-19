//
//  AddLocationView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//

import SwiftUI
import NMapsMap

struct AddLocationView: View {
    @ObservedObject var viewModel: AddMeetingViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Text("원하는 장소를 터치해주세요")
            .font(.headline)
        ZStack(alignment: .bottomTrailing) {
            MapView(isMarkerEnabled: true, viewModel: viewModel)
                .navigationBarHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            VStack{
                Text(viewModel.meeting.meetingAddress ?? "지정 된 장소 없음")
                    .font(.headline)
                            .multilineTextAlignment(.center)
                
                HStack {
                    Button("선택") {
                        // 버튼 클릭 시 이전 화면으로 돌아가기
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 100, height: 50)
                    .background(Color.blue)
                    .cornerRadius(30)
                    .padding(.bottom, 20)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    AddLocationView(viewModel: AddMeetingViewModel())
}

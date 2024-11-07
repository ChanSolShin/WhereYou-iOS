
//  EditMeetingView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import SwiftUI
import CoreLocation
import NMapsMap
import Foundation

struct EditMeetingView: View {
    @State private var showEditLocationModal = false // 모달을 제어할 변수
    @Environment(\.dismiss) var dismiss // 모달 닫기
    
    var body: some View {
        NavigationStack {
            VStack {
                
                Button(action: {
                    showEditLocationModal = true
                }) {
                    Text("모임 위치 수정")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
            }
            .sheet(isPresented: $showEditLocationModal) {
                AddLocationView(viewModel: AddMeetingViewModel())
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss() // 뒤로가기
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
}



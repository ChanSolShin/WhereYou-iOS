//
//  ReportView.swift
//  iOS_Project
//
//  Created by CHOI on 11/5/24.
//

import SwiftUI

struct ReportView: View {
    @ObservedObject private var viewModel = ReportViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("오류 신고")
                .font(.title)
                .bold()
                .padding(.top)
            
            Text("신고내용")
                .font(.headline)
                .foregroundColor(Color.black)
            
            TextEditor(text: $viewModel.reportContent)
                .padding()
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray, lineWidth: 1)
                )
                .background(Color.white)
                .frame(height: 200)
                .overlay(
                    Text(viewModel.reportContent.isEmpty ? "ex) 신고내용을 입력해주세요. (10자 이상)" : "")
                        .foregroundColor(.gray)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 25),
                    alignment: .topLeading
                )
            
            Spacer()
            
            Button(action: {
                viewModel.submitReport()
            }) {
                Text("신고하기")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            if let statusMessage = viewModel.submissionStatus {
                Text(statusMessage)
                    .foregroundColor(.gray)
                    .padding(.top)
            }
        }
        .padding()
        
    }
}

//
//  PermissionRequiredView.swift
//  iOS_Project
//
//  Created by CHOI on 11/7/24.
//

// 위치 권한이 항상 허용이 아닐 경우, 설정으로 유도하는 뷰

import SwiftUI

struct PermissionRequiredView: View{
    var body: some View{
        VStack(spacing: 20){
            Text("앱 사용을 위해 위치 권한을 항상 허용으로 설정해 주세요. ")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("설정에서 항상 허용으로 변경하기"){
                if let url = URL(string: UIApplication.openSettingsURLString){
                    UIApplication.shared.open(url)
                }
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
    }
}

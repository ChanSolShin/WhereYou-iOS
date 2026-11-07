//
//  SignUpButtonStyle.swift
//  iOS_Project
//
//  Created by 최용훈 on 06/11/26.
//

import SwiftUI

// 회원가입 단계의 채워진 버튼 (인증번호 전송/확인, 다음)
// 배경과 여백을 라벨 안에 그려 버튼 영역 전체가 탭되도록 함
struct SignUpFilledButtonStyle: ButtonStyle {
    let isActive: Bool
    var width: CGFloat? = nil       // nil이면 가로 전체
    var height: CGFloat? = nil
    var cornerRadius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil)
            .background(isActive ? Color.blue : Color.gray)
            .foregroundColor(.white)
            .cornerRadius(cornerRadius)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// 회원가입 단계의 글자 버튼 (뒤로, 취소)
// 여백까지 탭되도록 라벨 안에 여백 추가
struct SignUpTextButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .foregroundColor(color)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

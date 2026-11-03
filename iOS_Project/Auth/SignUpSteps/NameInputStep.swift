//
//  NameInputStep.swift
//  iOS_Project
//
//  Created by 최용훈 on 03/11/26.
//

import SwiftUI

// 회원가입 이름 입력 단계 (이메일 가입 / 소셜 가입 공통)
struct NameInputStep: View {
    @Binding var name: String

    var body: some View {
        VStack {
            Text("이름을 입력하세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                TextField("이름", text: $name)
                    .font(.system(size: 20))
            }
            .padding()
            .glassSurface(radius: 10)
            .cornerRadius(8)
            .padding(.horizontal, 30)

            Text("이름은 앱 내에서 친구에게 표시될 닉네임으로 사용됩니다.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    // 한글 2~10자 또는 영문 2자 이상 (단어 사이 공백 허용)
    static func isValid(_ name: String) -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let koreanNameRegex = "^[가-힣]{2,10}$"
        let englishNameRegex = "^[A-Za-z]{2,}(\\s[A-Za-z]+)*$"
        let namePredicate = NSPredicate(format: "SELF MATCHES %@ OR SELF MATCHES %@", koreanNameRegex, englishNameRegex)
        return namePredicate.evaluate(with: trimmedName)
    }
}

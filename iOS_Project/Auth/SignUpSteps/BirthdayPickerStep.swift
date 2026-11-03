//
//  BirthdayPickerStep.swift
//  iOS_Project
//
//  Created by 최용훈 on 03/11/26.
//

import SwiftUI

// 생년월일 휠 피커 (회원가입 / 소셜 가입 / 마이페이지 공통)
// birthday: "yyyyMMdd" 문자열 (이메일 찾기 조회 형식과 동일)
struct BirthdayWheelPicker: View {
    @Binding var birthday: String

    var body: some View {
        DatePicker("생년월일", selection: Binding(
            get: { Self.date(from: birthday) ?? Self.defaultDate },
            set: { birthday = Self.string(from: $0) }
        ), in: ...Date(), displayedComponents: [.date])
        .datePickerStyle(.wheel)
        .environment(\.locale, Locale(identifier: "ko_KR"))
        .labelsHidden()
    }

    // 값이 없거나 날짜로 변환할 수 없는 기존 값이면 20년 전 오늘로 표시
    static var defaultDate: Date {
        Calendar.current.date(byAdding: .year, value: -20, to: Date()) ?? Date()
    }

    static func date(from birthday: String) -> Date? {
        guard birthday.count == 8 else { return nil }
        return formatter.date(from: birthday)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        formatter.isLenient = false
        return formatter
    }()
}

// 회원가입 생년월일 입력 단계 (선택 입력)
struct BirthdayPickerStep: View {
    @Binding var wantsToInput: Bool
    @Binding var birthday: String

    var body: some View {
        VStack {
            Toggle(isOn: $wantsToInput) {
                Text("생년월일 입력")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 30)

            if wantsToInput {
                BirthdayWheelPicker(birthday: $birthday)
                    .padding(.horizontal, 30)
            }
            Text("생년월일은 사용자의 생일 알림 기능에만 사용됩니다. 앱 내 다른 용도로는 사용되지 않습니다.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 30)
        }
        .onChange(of: wantsToInput) { isOn in
            // 켜면 피커에 보이는 날짜로 바로 입력, 끄면 입력값 제거
            birthday = isOn ? BirthdayWheelPicker.string(from: BirthdayWheelPicker.defaultDate) : ""
        }
    }

    // 입력하지 않거나 8자리 숫자일 때 다음 단계 가능
    static func isValid(wantsToInput: Bool, birthday: String) -> Bool {
        guard wantsToInput else { return true }
        let trimmedBirthday = birthday.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedBirthday.count == 8 && trimmedBirthday.allSatisfy { $0.isNumber }
    }
}

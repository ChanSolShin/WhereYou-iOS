//
//  PhoneVerificationSteps.swift
//  iOS_Project
//
//  Created by 최용훈 on 03/11/26.
//

import SwiftUI

// 회원가입 휴대전화 입력 단계 (이메일 가입 / 소셜 가입 공통)
// 인증번호 전송 처리는 각 ViewModel에서 (이메일 가입: 중복 확인 후 전송, 소셜 가입: 바로 전송)
struct PhoneNumberStep: View {
    let countryCodes: [CountryCode]
    @Binding var selectedCountry: CountryCode?
    @Binding var phoneNumber: String
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("휴대전화를 입력하세요 (- 없이)")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            HStack(spacing: 10) {
                Menu {
                    ForEach(countryCodes, id: \.id) { code in
                        Button(action: {
                            selectedCountry = code
                        }) {
                            Text("\(code.emoji) \(code.country) \(code.display)")
                                .font(.system(size: 14))
                        }
                    }
                } label: {
                    if let selected = selectedCountry {
                        Text("\(selected.emoji) \(selected.display)")
                            .font(.system(size: 14))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text("선택 ⬇️")
                            .font(.system(size: 14))
                    }
                }
                .frame(width: 90)

                TextField("휴대전화", text: $phoneNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: phoneNumber) { newValue in
                        if let limited = Self.limitedLength(newValue, countryCode: selectedCountry?.code) {
                            phoneNumber = limited
                        }
                    }
                    .font(.system(size: 20))
            }
            .padding()
            .glassSurface(radius: 10)
            .cornerRadius(8)
            .padding(.horizontal, 30)

            Button("인증번호 전송") {
                onSend()
            }
            .buttonStyle(SignUpFilledButtonStyle(isActive: isValid))
            .padding(.horizontal, 30)
            .disabled(!isValid)

            Text("전화번호는 친구를 찾고 추가하는 데 사용됩니다.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }

    private var isValid: Bool {
        Self.isValid(phoneNumber, countryCode: selectedCountry?.code)
    }

    // 국가코드별 전화번호 유효성 검사
    static func isValid(_ phoneNumber: String, countryCode: String?) -> Bool {
        guard let countryCode else { return false }
        let phone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)

        // 공백 포함 여부 확인
        if phone.contains(" ") { return false }

        switch countryCode {
        case "+82":
            if phone.hasPrefix("010") {
                return phone.count == 11
            } else if phone.hasPrefix("10") {
                return phone.count == 10
            } else {
                return false
            }
        case "+1":
            return phone.count == 10
        case "+44":
            return phone.count == 10 || phone.count == 11
        default:
            return !phone.isEmpty
        }
    }

    // users 문서 phoneNumber 저장 형식으로 변환 (국가코드 + 번호)
    // +82: 010으로 시작할 경우 10으로 시작하도록 변환
    static func formatted(_ phoneNumber: String, countryCode: String) -> String {
        if countryCode == "+82" {
            var digits = phoneNumber
            if digits.hasPrefix("0") {
                digits = String(digits.dropFirst())
            }
            return countryCode + digits
        } else {
            if phoneNumber.hasPrefix("+") {
                return phoneNumber
            }
            return countryCode + phoneNumber
        }
    }

    // 국가코드별 최대 길이 초과 시 잘라낸 값 (초과하지 않으면 nil)
    private static func limitedLength(_ phoneNumber: String, countryCode: String?) -> String? {
        guard let countryCode else { return nil }
        let maxLength: Int
        switch countryCode {
        case "+82":
            if phoneNumber.hasPrefix("010") {
                maxLength = 11
            } else if phoneNumber.hasPrefix("10") {
                maxLength = 10
            } else {
                return nil
            }
        case "+1":
            maxLength = 10
        case "+44":
            maxLength = 11
        default:
            maxLength = 15
        }
        return phoneNumber.count > maxLength ? String(phoneNumber.prefix(maxLength)) : nil
    }
}

// 회원가입 인증번호 입력 단계 (이메일 가입 / 소셜 가입 공통)
struct VerificationCodeStep: View {
    @Binding var verificationCode: String
    let timerValue: Int
    let isEnabled: Bool
    let onResend: () -> Void
    let onVerify: () -> Void

    var body: some View {
        VStack(spacing: 15) {
            Text("인증번호를 입력하세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("인증번호 입력", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .glassSurface(radius: 10)
                        .cornerRadius(8)
                    // 타이머 표시
                    Text("\(String(format: "%02d:%02d", timerValue / 60, timerValue % 60))")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.trailing, 10)
                }

                Button("재전송") {
                    onResend()
                }
                .foregroundColor(isEnabled ? .blue : .gray)
                .disabled(!isEnabled)
            }
            .padding(.horizontal, 30)

            Button("인증번호 확인") {
                onVerify()
            }
            .buttonStyle(SignUpFilledButtonStyle(isActive: isEnabled))
            .padding(.horizontal, 30)
            .disabled(!isEnabled)

            Text("인증번호가 오지 않았다면, 번호가 잘못되었을 수 있습니다.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
    }
}

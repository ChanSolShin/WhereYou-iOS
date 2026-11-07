//
//  FindEmailView.swift
//  iOS_Project
//
//  Created by CHOI on 10/31/24.
//

import SwiftUI

struct FindEmailView: View {
    @StateObject private var viewModel = FindEmailViewModel()
    @State private var showAlert = false
    @State private var alertMessage = ""

    @State private var countryCodes: [CountryCode] = []
    @State private var selectedCountry: CountryCode? = nil
    @State private var showBirthdayPicker = false

    // 생년월일 표시 (비어 있으면 입력 안 함)
    private var birthdayDisplayText: String {
        guard let date = BirthdayWheelPicker.date(from: viewModel.model.birthday) else {
            return "생년월일 (선택)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }

    // 처음 펼칠 때 피커에 보이는 날짜를 바로 입력값으로 사용 (표시와 조회 값 일치)
    private func toggleBirthdayPicker() {
        hideKeyboard()
        if !showBirthdayPicker && viewModel.model.birthday.isEmpty {
            viewModel.model.birthday = BirthdayWheelPicker.string(from: BirthdayWheelPicker.defaultDate)
        }
        withAnimation {
            showBirthdayPicker.toggle()
        }
    }

    var body: some View {
        ScrollView {
            VStack {
                Text("웨어유")
                    .font(.largeTitle)
                    .padding(.top, 20)
                    .padding(.bottom, 60)
                    .fontWeight(.bold)
                
                VStack {
                    // 이름 입력
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("이름을 입력하세요", text: $viewModel.model.name)
                            .onChange(of: viewModel.model.name) { newValue in
                                viewModel.model.name = newValue.replacingOccurrences(of: " ", with: "")
                            }
                    }
                    .padding()
                    .glassSurface(radius: 8)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // 생년월일 선택 (회원가입, 회원정보 수정과 같은 휠 피커, 가입 시 입력한 경우만)
                    Button(action: toggleBirthdayPicker) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                                .imageScale(.small)
                            Text(birthdayDisplayText)
                                .foregroundColor(viewModel.model.birthday.isEmpty ? .gray : .primary)
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: showBirthdayPicker ? "chevron.up" : "chevron.down")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .glassSurface(radius: 8)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    if showBirthdayPicker {
                        BirthdayWheelPicker(birthday: $viewModel.model.birthday)
                            .frame(maxWidth: .infinity)
                        if !viewModel.model.birthday.isEmpty {
                            Button("생년월일 지우기") {
                                viewModel.model.birthday = ""
                                withAnimation {
                                    showBirthdayPicker = false
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.bottom, 10)
                        }
                    }

                    // 전화번호 입력 (국가 코드 포함)
                    HStack(spacing: 2) {
                        Image(systemName: "phone")
                            .foregroundColor(.gray)
                            .imageScale(.small)

                        Menu {
                            ForEach(countryCodes, id: \.id) { code in
                                Button(action: {
                                    selectedCountry = code
                                    viewModel.selectedCountryCode = code.code
                                }) {
                                    Text("\(code.emoji) \(code.country) (\(code.code))")
                                        .font(.system(size: 14))
                                }
                            }
                        } label: {
                            if let selected = selectedCountry {
                                Text("\(selected.emoji) (\(selected.code))")
                                    .font(.system(size: 14))
                            } else {
                                Text("선택 ⬇️")
                                    .font(.system(size: 14))
                            }
                        }
                        .frame(width: 90)

                        TextField("전화번호 ( - 없이 )", text: $viewModel.model.phoneNumber)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.model.phoneNumber) { newValue in
                                if let selected = selectedCountry {
                                    if selected.code == "+82" {
                                        if newValue.hasPrefix("010"), newValue.count > 11 {
                                            viewModel.model.phoneNumber = String(newValue.prefix(11))
                                        } else if newValue.hasPrefix("10"), newValue.count > 10 {
                                            viewModel.model.phoneNumber = String(newValue.prefix(10))
                                        }
                                    } else if selected.code == "+1", newValue.count > 10 {
                                        viewModel.model.phoneNumber = String(newValue.prefix(10))
                                    } else if selected.code == "+44", newValue.count > 11 {
                                        viewModel.model.phoneNumber = String(newValue.prefix(11))
                                    } else if newValue.count > 15 {
                                        viewModel.model.phoneNumber = String(newValue.prefix(15))
                                    }
                                }
                            }
                    }
                    .padding()
                    .glassSurface(radius: 8)
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                    // 이메일 찾기 버튼
                    Button(action: {
                        hideKeyboard()

                        // 입력값 유효성 검사
                        if viewModel.model.name.isEmpty {
                            alertMessage = "이름을 입력해주세요."
                            showAlert = true
                            return
                        }

                        viewModel.findEmail { success in
                            if !success {
                                alertMessage = viewModel.errorMessage ?? "일치하는 계정이 없습니다."
                                showAlert = true
                            }
                        }
                    }) {
                        Text("이메일 찾기")
                            .frame(width: 200, height: 50)
                            .background(viewModel.isPhoneNumberValid ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!viewModel.isPhoneNumberValid)
                    .padding(.bottom, 10)
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("알림"), message: Text(alertMessage))
                    }

                    // 조회 결과 (로그인 수단 안내, 이메일은 마스킹)
                    if let resultMessage = viewModel.resultMessage {
                        Text(resultMessage)
                            .foregroundColor(.blue)
                            .multilineTextAlignment(.center)
                            .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle("이메일 찾기")
        }
        .background(GlassBackdrop())
        .onAppear {
            countryCodes = loadCountryCodes()
        }
    }
}

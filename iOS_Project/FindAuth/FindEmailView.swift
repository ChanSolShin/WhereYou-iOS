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
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                    // 생년월일 입력
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("생년월일(8자리)", text: $viewModel.model.birthday)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.model.birthday) { newValue in
                                if newValue.count > 8 {
                                    viewModel.model.birthday = String(newValue.prefix(8))
                                }
                            }
                            .font(.system(size: 16))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

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
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
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
                        if viewModel.model.birthday.isEmpty {
                            alertMessage = "생년월일을 입력해주세요."
                            showAlert = true
                            return
                        }
                        if viewModel.model.birthday.count != 8 {
                            alertMessage = "생년월일은 8자리로 입력해주세요."
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

                    // 결과 이메일 표시
                    if let foundEmail = viewModel.foundEmail {
                        Text("사용 중인 이메일: \(foundEmail)")
                            .foregroundColor(.blue)
                            .padding()
                    }

                    Spacer()
                }
            }
            .navigationTitle("이메일 찾기")
        }
        .onAppear {
            countryCodes = loadCountryCodes()
        }
    }
}

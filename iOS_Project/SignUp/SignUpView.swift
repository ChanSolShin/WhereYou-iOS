//
//  SignUpView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel: SignUpViewModel // viewModel의 초기화 접근 수준 조정
    @Environment(\.presentationMode) var presentationMode
    @State private var showPassword = false
    @State private var offset: CGFloat = 0
    
    // 생성자 추가
    init(viewModel: SignUpViewModel = SignUpViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    Text("이름")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.top, 50)
                    
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("이름", text: $viewModel.realName)
                            .font(.system(size: 16))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    Text("생년월일")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                        .font(.caption)
                        .padding(.horizontal, 10)
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("생년월일(8자리)", text: $viewModel.birthday)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.birthday) { newValue in
                                if newValue.count > 8 {
                                    viewModel.birthday = String(newValue.prefix(8))
                                }
                            }
                            .font(.system(size: 16))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    Text("휴대폰번호")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                        .font(.caption)
                        .padding(.horizontal, 10)
                    
                    HStack {
                        Image(systemName: "phone")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("휴대폰번호 ( - 없이)", text: $viewModel.phoneNumber)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.phoneNumber) { newValue in
                                if newValue.count > 11 {
                                    viewModel.phoneNumber = String(newValue.prefix(11))
                                }
                            }
                            .font(.system(size: 16))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    Text("이메일")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                        .font(.caption)
                        .padding(.horizontal, 10)
                    
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("이메일", text: $viewModel.username)
                            .keyboardType(.emailAddress)
                            .font(.system(size: 16))
                            .autocapitalization(.none)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
                    .padding(.horizontal, 30)
                    
                    if !viewModel.isValidEmail && !viewModel.username.isEmpty {
                        Text("유효한 이메일 주소가 아닙니다.")
                            .padding(.leading, 200)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 10)
                    }
                    
                    Text("비밀번호")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                        .font(.caption)
                        .padding(.horizontal, 10)
                    
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        if showPassword {
                            TextField("비밀번호", text: $viewModel.password)
                                .font(.system(size: 16))
                                .autocapitalization(.none)
                        } else {
                            SecureField("비밀번호", text: $viewModel.password)
                                .font(.system(size: 16))
                                .autocapitalization(.none)
                        }
                        
                        Button(action: {
                            showPassword.toggle()
                        }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .imageScale(.small)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    Text("비밀번호확인")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 25)
                        .font(.caption)
                        .padding(.horizontal, 10)
                    
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        SecureField("비밀번호확인", text: $viewModel.confirmPassword)
                            .font(.system(size: 16))
                            .autocapitalization(.none)
                        
                        if viewModel.confirmPassword.isEmpty || viewModel.password.isEmpty {
                            EmptyView()
                        } else if viewModel.passwordMatches {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal, 30)
                    
                    Button(action: {
                        viewModel.signUp()
                        if viewModel.signUpSuccess {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        Text("회원가입")
                            .padding(.leading, 250)
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .padding()
                            .cornerRadius(8)
                            .opacity(viewModel.successCreate ? 0.5 : 1)
                    }
                    .disabled(viewModel.successCreate)
                    .padding(.top, 40)
                    
                    Spacer()
                }
            }
        }
        .navigationTitle("회원가입")
        .alert(isPresented: .constant(viewModel.signUpErrorMessage != nil)) {
            Alert(title: Text("회원가입 실패"), message: Text(viewModel.signUpErrorMessage ?? ""), dismissButton: .default(Text("확인")))
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(viewModel: SignUpViewModel())
    }
}

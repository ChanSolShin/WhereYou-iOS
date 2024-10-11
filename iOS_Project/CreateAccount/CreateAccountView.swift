// CreateAccountView.swift
import SwiftUI

struct CreateAccountView: View {
    @StateObject private var viewModel = CreateAccountViewModel()

    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        NavigationView {
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
                        //글자수 제한
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
                    // 글자수 제한
                        .onChange(of:  viewModel.phoneNumber) { newValue in
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
                
                // 이메일 입력 필드
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
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .padding(.horizontal, 30)
                
                // 이메일 유효성 검사 메시지
                if !viewModel.isValidEmail && !viewModel.username.isEmpty {
                    Text("유효한 이메일 주소가 아닙니다.")
                        .padding(.leading, 200)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 10)
                }
                
                // 비밀번호 입력 필드
                Text("비밀번호")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 25)
                    .font(.caption)
                    .padding(.horizontal, 10)
                HStack {
                    Image(systemName: "lock")
                        .foregroundColor(.gray)
                        .imageScale(.small)
                    SecureField("비밀번호", text: $viewModel.password)
                        .font(.system(size: 16))
                        .autocapitalization(.none)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 30)
                
                // 비밀번호 확인 입력 필드
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
                    }
                    else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                .padding(.horizontal, 30)
             
                
                // 버튼을 탭 했을때 서버로 텍스트박스 필드 내용 전송 하는 로직 구성 해야함
                Button(action: { // 첫 화면으로 돌아감
                    presentationMode.wrappedValue.dismiss()
                           }) {
                               Text("회원가입")
                                   .font(.system(size: 20))
                                   .foregroundColor(.blue)
                                   .padding()
                                   .frame(width: 150, height: 50)
                                   .cornerRadius(8)
                                   .opacity(viewModel.successCreate ? 0.5 : 1)
                           }
                            // 모든 텍스트 필드가 제대로 채워지지 않으면 회원가입 버튼을 누를 수 없음
                           .disabled(viewModel.successCreate)
                
                           .padding(.top, 20)
                
                Spacer()
            }
        }
        .navigationTitle("회원가입")
        .font(.largeTitle)
    }
}

// 프리뷰용 코드
struct CreateAccountView_Previews: PreviewProvider {
    static var previews: some View {
        CreateAccountView()
    }
}

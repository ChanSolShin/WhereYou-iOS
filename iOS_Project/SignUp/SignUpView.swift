import SwiftUI

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showPassword = false
    @State private var currentStep = 0
    @State private var showAlert = false
    @State private var emailChecked = false
    
    var body: some View {
        VStack {
            Spacer()
            
            Group {
                switch currentStep {
                case 0:
                    nameStep
                case 1:
                    birthdayStep
                case 2:
                    phoneNumberStep
                case 3:
                    emailStep
                case 4:
                    passwordStep
                case 5:
                    confirmPasswordStep
                default:
                    Text("회원가입 완료!")
                }
            }
            .transition(.move(edge: .leading))

            Spacer()
            
            HStack {
                if currentStep > 0 {
                    Button("뒤로") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                    .padding()
                    .foregroundColor(.blue)
                }
                
                Spacer()
                
                Button(currentStep == 5 ? "회원가입" : "다음") {
                    withAnimation {
                        if currentStep == 5 {
                            viewModel.signUp()
                            if viewModel.signUpSuccess {
                                showAlert = true
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        } else {
                            currentStep += 1
                        }
                    }
                }
                .padding()
                .frame(width: 200, height: 50)
                .background(isNextButtonEnabled ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(25)
                .font(.title3)
                .disabled(!isNextButtonEnabled)
            }
            .padding(.bottom, 40)
        }
        .padding()
        .navigationTitle("회원가입")
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("회원가입 성공"),
                message: Text("회원가입이 성공적으로 완료되었습니다."),
                dismissButton: .default(Text("확인"))
            )
        }
    }
    
    private var isNextButtonEnabled: Bool {
        switch currentStep {
        case 0: return !viewModel.realName.isEmpty
        case 1: return !viewModel.birthday.isEmpty && viewModel.birthday.count == 8
        case 2: return !viewModel.phoneNumber.isEmpty && viewModel.phoneNumber.count == 11
        case 3: return viewModel.isValidEmail && emailChecked
        case 4: return viewModel.password.count >= 6
        case 5: return viewModel.passwordMatches
        default: return false
        }
    }

    // 이름 입력 필드
    private var nameStep: some View {
        VStack {
            Text("이름을 입력하세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                TextField("이름", text: $viewModel.realName)
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 30)
        }
    }

    // 생년월일 입력 필드
    private var birthdayStep: some View {
        VStack {
            Text("생년월일을 입력하세요 (8자리)")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
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
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 30)
        }
    }

    // 휴대전화 입력 필드
    private var phoneNumberStep: some View {
        VStack {
            Text("휴대전화를 입력하세요 (- 없이)")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                TextField("휴대전화 ( - 없이)", text: $viewModel.phoneNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.phoneNumber) { newValue in
                        if newValue.count > 11 {
                            viewModel.phoneNumber = String(newValue.prefix(11))
                        }
                    }
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 30)
        }
    }

    // 이메일 입력 필드
    private var emailStep: some View {
        VStack {
            Text("이메일을 입력하세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack {
                Image(systemName: "person")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                TextField("이메일", text: $viewModel.username)
                    .font(.system(size: 20))
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .onChange(of: viewModel.username) { _ in
                        emailChecked = false
                        viewModel.signUpErrorMessage = nil
                        viewModel.signUpErrorMessageColor = .red
                    }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 30)
            
            // 유효하지 않은 이메일 주소일 경우 에러 메시지 표시
            if !viewModel.isValidEmail && !viewModel.username.isEmpty {
                Text("유효한 이메일 주소가 아닙니다.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 200)
            }

            // 이메일 확인 버튼
            Button("이메일 확인") {
                viewModel.signUpErrorMessage = nil

                if viewModel.isValidEmail {
                    viewModel.checkEmailAvailability { isAvailable in
                        if isAvailable {
                            emailChecked = true
                            viewModel.signUpErrorMessage = "가입 가능한 이메일입니다."
                            viewModel.signUpErrorMessageColor = .green
                        } else {
                            emailChecked = false
                            viewModel.signUpErrorMessage = "이미 가입된 이메일입니다."
                            viewModel.signUpErrorMessageColor = .red
                        }
                    }
                }
            }
            .foregroundColor(viewModel.isValidEmail ? .blue : .gray) // 유효한 이메일일 때만 버튼 활성화
            .padding(.top, 10)
            .disabled(!viewModel.isValidEmail)

            if let errorMessage = viewModel.signUpErrorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(viewModel.signUpErrorMessageColor)
                    .font(.caption)
                    .padding(.top, 10)
            }
        }
    }

    // 비밀번호 입력 필드
    private var passwordStep: some View {
        VStack {
            Text("비밀번호를 입력하세요 (6자 이상)")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                if showPassword {
                    TextField("비밀번호", text: $viewModel.password)
                        .autocapitalization(.none)
                        .font(.system(size: 20))
                } else {
                    SecureField("비밀번호", text: $viewModel.password)
                        .autocapitalization(.none)
                        .font(.system(size: 20))
                }
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .imageScale(.small)
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 30)
            
            if viewModel.password.count < 6 && !viewModel.password.isEmpty {
                Text("비밀번호를 6자리 이상 입력해 주세요.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 200)
            }
        }
    }

    // 비밀번호 확인 입력 필드
    private var confirmPasswordStep: some View {
        VStack {
            Text("비밀번호를 확인하세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack {
                Image(systemName: "lock")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                SecureField("비밀번호 확인", text: $viewModel.confirmPassword)
                    .autocapitalization(.none)
                    .font(.system(size: 20))
                
                if viewModel.passwordMatches {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal, 30)
        }
    }
}

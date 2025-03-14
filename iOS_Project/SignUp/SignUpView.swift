import SwiftUI

// MARK: - CountryCode 모델
struct CountryCode: Codable, Identifiable, Hashable {
    var id: String { code }
    let code: String    //전화번호 인증용
    let country: String
    let emoji: String
    var display: String {"(\(code))"}  // UI 표시용 국가코드
}

// MARK: - JSON 파일 불러오기 함수
func loadCountryCodes() -> [CountryCode] {
    guard let url = Bundle.main.url(forResource: "country_codes", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let codes = try? JSONDecoder().decode([CountryCode].self, from: data) else {
        return []
    }
    return codes
}

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showPassword = false
    @State private var currentStep = 0
    @State private var showAlert = false
    @State private var emailChecked = false
    @State private var countryCodes: [CountryCode] = []
    @State private var selectedCountry: CountryCode? = nil
    
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
                    verificationCodeStep
                case 4:
                    emailStep
                case 5:
                    passwordStep
                case 6:
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
                
                Button(currentStep == 6 ? "회원가입" : "다음") {
                    withAnimation {
                        if currentStep == 6 {
                            // 회원가입 버튼 액션 (기능 미구현)
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
        .onAppear {
            countryCodes = loadCountryCodes()
            selectedCountry = nil
        }
    }
    
    private var isNextButtonEnabled: Bool {
        switch currentStep {
        case 0: return !viewModel.realName.isEmpty
        case 1: return !viewModel.birthday.isEmpty && viewModel.birthday.count == 8
        case 2: return isPhoneNumberValid
        case 3: return !viewModel.verificationCode.isEmpty
        case 4: return viewModel.isValidEmail && emailChecked
        case 5: return viewModel.password.count >= 6
        case 6: return viewModel.passwordMatches
        default: return false
        }
    }
    
    // 국가코드별 전화번호 유효성 검사
    private var isPhoneNumberValid: Bool {
        guard let selected = selectedCountry else { return false }
        let phone = viewModel.phoneNumber
        
        switch selected.code {
        case "+82":
            // "010"으로 시작: 11자리
            // "10"으로 시작: 10자리여야 함
            if phone.hasPrefix("010") {
                return phone.count == 11
            } else if phone.hasPrefix("10") {
                return phone.count == 10
            } else {
                return false
            }
        case "+1":
            // 미국: 10자리
            return phone.count == 10
        case "+44":
            // 영국: 10자리 또는 11자리
            return phone.count == 10 || phone.count == 11
        default:
            // 기타 국가: 비어있지 않음을 체크
            return !phone.isEmpty
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
                
                TextField("휴대전화", text: $viewModel.phoneNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: viewModel.phoneNumber) { newValue in
                        if let selected = selectedCountry {
                            if selected.code == "+82" {
                                if newValue.hasPrefix("010") {
                                    if newValue.count > 11 {
                                        viewModel.phoneNumber = String(newValue.prefix(11))
                                    }
                                } else if newValue.hasPrefix("10") {
                                    if newValue.count > 10 {
                                        viewModel.phoneNumber = String(newValue.prefix(10))
                                    }
                                } else {
                                    viewModel.phoneNumber = newValue
                                }
                            } else if selected.code == "+1" {
                                if newValue.count > 10 {
                                    viewModel.phoneNumber = String(newValue.prefix(10))
                                }
                            } else if selected.code == "+44" {
                                if newValue.count > 11 {
                                    viewModel.phoneNumber = String(newValue.prefix(11))
                                }
                            } else {
                                if newValue.count > 15 {
                                    viewModel.phoneNumber = String(newValue.prefix(15))
                                }
                            }
                        }
                    }
                    .font(.system(size: 20))
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal, 30)
            
            Button("인증번호 전송") {
                // 인증번호 전송 기능
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .padding(.horizontal, 30)
            .disabled(!isPhoneNumberValid)
        }
    }
    
    private var verificationCodeStep: some View {
        VStack(spacing: 15) {
            Text("인증번호를 입력하세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
            
            HStack(spacing: 10) {
                ZStack(alignment: .trailing) {
                    TextField("인증번호 입력", text: $viewModel.verificationCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    Text("05:00")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.trailing, 10)
                }
                
                Button("재전송") {
                    // 인증번호 재전송 기능
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 30)
            
            Button("인증번호 확인") {
                // 인증번호 확인 기능
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.blue)
            .foregroundColor(.white)
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
            
            if !viewModel.isValidEmail && !viewModel.username.isEmpty {
                Text("유효한 이메일 주소가 아닙니다.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.leading, 200)
            }
            
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
            .foregroundColor(viewModel.isValidEmail ? .blue : .gray)
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

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

// MARK: - ActiveAlert list
enum SignUpActiveAlert: Identifiable {
    case codeSent
    case verificationSuccess
    case verificationFailure
    case signUpSuccess
    
    var id: Int { hashValue }
}

struct SignUpView: View {
    @StateObject private var viewModel = SignUpViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showPassword = false
    @State private var currentStep = 0
    @State private var emailChecked = false
    @State private var countryCodes: [CountryCode] = []
    @State private var selectedCountry: CountryCode? = nil
    @State private var activeAlert: SignUpActiveAlert? = nil
    
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
                
                if currentStep != 2 {
                    Button(currentStep == 6 ? "회원가입" : "다음") {
                        withAnimation {
                            if currentStep == 6 {
                                // 회원가입 버튼 액션: 이메일, 비밀번호 입력 후 회원가입
                                viewModel.signUp()
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
            }
            .padding(.bottom, 40)
        }
        .padding()
        .navigationTitle("회원가입")
        // 기존 회원가입 성공 alert를 ActiveAlert로 통합
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .codeSent:
                return Alert(
                    title: Text("인증번호 전송"),
                    message: Text("인증번호가 전송되었습니다."),
                    dismissButton: .default(Text("확인"), action: {
                        withAnimation {
                            currentStep = 3
                        }
                    })
                )
            case .verificationSuccess:
                return Alert(
                    title: Text("인증 성공"),
                    message: Text("인증번호가 일치합니다."),
                    dismissButton: .default(Text("확인"))
                )
            case .verificationFailure:
                return Alert(
                    title: Text("인증 실패"),
                    message: Text("인증번호가 일치하지 않습니다."),
                    dismissButton: .default(Text("확인"))
                )
            case .signUpSuccess:
                return Alert(
                    title: Text("회원가입 성공"),
                    message: Text("회원가입이 성공적으로 완료되었습니다."),
                    dismissButton: .default(Text("확인"), action: {
                        // 회원가입 성공 후 LoginView로 이동
                        presentationMode.wrappedValue.dismiss()
                    })
                )
            }
        }
        .onAppear {
            countryCodes = loadCountryCodes()
        }
        // ViewModel 상태 변화에 따른 alert 표시
        .onChange(of: viewModel.isVerificationCodeSent) { newValue in
            if newValue {
                activeAlert = .codeSent
            }
        }
        .onChange(of: viewModel.isVerificationSuccessful) { newValue in
            if newValue {
                activeAlert = .verificationSuccess
            }
        }
        .onChange(of: viewModel.signUpErrorMessage) { newValue in
            if currentStep == 3, newValue == "인증번호가 일치하지 않습니다." {
                activeAlert = .verificationFailure
            }
        }
        // 회원가입 성공 상태 변화 감지
        .onChange(of: viewModel.signUpSuccess) { success in
            if success {
                activeAlert = .signUpSuccess
            }
        }
    }
    
    private var isNextButtonEnabled: Bool {
        switch currentStep {
        case 0: return !viewModel.realName.isEmpty
        case 1: return !viewModel.birthday.isEmpty && viewModel.birthday.count == 8
        case 2: return false  // 전화번호 입력 단계에서는 다음 버튼 비활성화
        case 3: return viewModel.isVerificationSuccessful  // 인증 성공 시에만 다음 버튼 활성화
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
            // "10"으로 시작: 10자리
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
                if let selected = selectedCountry {
                    let fullPhoneNumber = selected.code + viewModel.phoneNumber
                    viewModel.sendVerificationCode(fullPhoneNumber: fullPhoneNumber)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(isPhoneNumberValid ? Color.blue : Color.gray)
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
                    // 타이머 표시
                    Text("\(String(format: "%02d:%02d", viewModel.timerValue/60, viewModel.timerValue % 60))")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.trailing, 10)
                }
                
                Button("재전송") {
                    // 인증번호 재전송 기능
                    if let selected = selectedCountry {
                        let fullPhoneNumber = selected.code + viewModel.phoneNumber
                        viewModel.resendCode(fullPhoneNumber: fullPhoneNumber)
                    }
                }
                .foregroundColor(.blue)
            }
            .padding(.horizontal, 30)
            
            Button("인증번호 확인") {
                // 인증번호 확인 기능
                viewModel.verifyCode()
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
            
            VStack(alignment: .leading) {
                if !viewModel.isValidEmail && !viewModel.username.isEmpty {
                    Text("유효한 이메일 주소가 아닙니다.")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                if let errorMessage = viewModel.signUpErrorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(viewModel.signUpErrorMessageColor)
                        .font(.caption)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 30)
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

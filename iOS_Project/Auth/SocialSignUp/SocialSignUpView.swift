//
//  SocialSignUpView.swift
//  iOS_Project
//
//  Created by 최용훈 on 31/10/26.
//

import SwiftUI

// 소셜 최초 로그인 후 회원정보 입력 화면 (이메일 회원가입과 같은 단계형 구성)
struct SocialSignUpView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @StateObject private var viewModel = SocialSignUpViewModel()
    @State private var showSafariView = false

    var body: some View {
        VStack {
            Text("회원정보 입력")
                .font(.headline)
                .padding(.top, 8)

            Spacer()

            Group {
                switch viewModel.step {
                case .phoneNumber:
                    phoneNumberStep
                case .verificationCode:
                    VerificationCodeStep(
                        verificationCode: $viewModel.verificationCode,
                        timerValue: viewModel.timerValue,
                        isEnabled: !viewModel.isPhoneVerified,
                        onResend: viewModel.resendCode,
                        onVerify: viewModel.verifyCode
                    )
                case .name:
                    NameInputStep(name: $viewModel.name)
                case .birthday:
                    BirthdayPickerStep(wantsToInput: $viewModel.wantsToInputBirthday, birthday: $viewModel.birthday)
                case .email:
                    emailStep
                case .terms:
                    termsStep
                }
            }
            .transition(.move(edge: .leading))

            Spacer()

            bottomButtons
        }
        .padding()
        .background(GlassBackdrop())
        // 알림은 이 하나로만 표시
        // 이 화면은 NavigationView 없이 앱 루트에 바로 붙어 있어, 기존 방식(Alert) 알림은
        // 루트의 업데이트 알림과 겹쳐 표시되지 않으므로 iOS 15 방식 API 사용
        .alert(
            viewModel.alert?.title ?? "",
            isPresented: Binding(
                get: { viewModel.alert != nil },
                set: { if !$0 { viewModel.alert = nil } }
            ),
            presenting: viewModel.alert
        ) { alert in
            alertActions(for: alert)
        } message: { alert in
            Text(alert.message)
        }
        // 가입 완료 후 세션 확립 실패 시 (users 문서는 저장된 상태라 재시도만)
        .onReceive(loginViewModel.$currentAlert) { alert in
            guard let alert else { return }
            if case .loginFailed(let message) = alert {
                viewModel.alert = .loginFailed(message)
            } else {
                viewModel.alert = .loginFailed("로그인에 실패했습니다. 다시 시도해주세요.")
            }
            loginViewModel.currentAlert = nil
        }
        .onChange(of: viewModel.result) { result in
            switch result {
            case .completed:
                loginViewModel.completeSocialSignUp()
            case .returnToLogin:
                loginViewModel.signOut(updateFirestore: false)
            case nil:
                break
            }
        }
        // 전체 화면에 ProgressView 오버레이 및 터치 차단
        .overlay(
            Group {
                if viewModel.isLoading || loginViewModel.isLoggingIn {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        )
        .disabled(viewModel.isLoading || loginViewModel.isLoggingIn)
    }

    // MARK: - 단계

    // 인증 완료 후 뒤로 돌아온 경우 번호 수정 없이 완료 상태만 표시
    @ViewBuilder
    private var phoneNumberStep: some View {
        if viewModel.isPhoneVerified {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text("휴대전화 인증이 완료되었습니다.")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        } else {
            PhoneNumberStep(
                countryCodes: viewModel.countryCodes,
                selectedCountry: $viewModel.selectedCountry,
                phoneNumber: $viewModel.phoneNumber,
                onSend: viewModel.sendVerificationCode
            )
        }
    }

    private var emailStep: some View {
        VStack {
            Text("이메일을 입력하세요 (선택)")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.gray)
                    .imageScale(.small)
                TextField("이메일", text: $viewModel.email)
                    .font(.system(size: 20))
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .onChange(of: viewModel.email) { _ in
                        viewModel.emailErrorMessage = nil
                    }
            }
            .padding()
            .glassSurface(radius: 10)
            .cornerRadius(10)
            .padding(.horizontal, 30)

            if let message = viewModel.emailErrorMessage {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
                    .padding(.horizontal, 30)
            } else if !viewModel.canProceed {
                Text("유효한 이메일 주소가 아닙니다.")
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.top, 4)
            }

            Text("친구가 이메일로 나를 찾을 때 사용됩니다. 비워 두어도 가입할 수 있습니다.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
                .padding(.horizontal, 30)
        }
    }

    private var termsStep: some View {
        VStack {
            Text("약관에 동의해주세요")
                .font(.title2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)

            Toggle(isOn: $viewModel.agreedToTerms) {
                Text("개인정보 처리방침에 동의합니다.")
                    .font(.subheadline)
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.horizontal, 30)
            .padding(.top, 10)

            Button(action: {
                showSafariView = true
            }) {
                Text("약관 확인하기")
                    .font(.caption)
                    .underline()
                    .foregroundColor(.blue)
            }
            .padding(.top, 10)
            .sheet(isPresented: $showSafariView) {
                SafariView(url: URL(string: "https://www.notion.so/1c3bd8a38451804eb200f4fd5e19ca22?pvs=4")!)
            }
        }
    }

    // MARK: - 하단 버튼

    private var bottomButtons: some View {
        HStack {
            if viewModel.step == .phoneNumber {
                Button("취소") {
                    viewModel.alert = .confirmCancel
                }
                .padding()
                .foregroundColor(.gray)
            } else {
                Button("뒤로") {
                    withAnimation {
                        hideKeyboard()
                        viewModel.goBack()
                    }
                }
                .padding()
                .foregroundColor(.blue)
            }

            Spacer()

            // 인증 전 휴대전화/인증번호 단계는 각 단계 버튼으로만 진행
            if viewModel.isPhoneVerified || (viewModel.step != .phoneNumber && viewModel.step != .verificationCode) {
                Button(viewModel.step == .terms ? "가입 완료" : "다음") {
                    withAnimation {
                        hideKeyboard()
                        viewModel.goNext()
                    }
                }
                .padding()
                .frame(width: 200, height: 50)
                .background(viewModel.canProceed ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(25)
                .font(.title3)
                .disabled(!viewModel.canProceed)
            }
        }
        .padding(.bottom, 40)
    }

    // MARK: - 알림

    @ViewBuilder
    private func alertActions(for alert: SocialSignUpAlert) -> some View {
        switch alert {
        case .codeSent:
            Button("확인") {
                withAnimation {
                    viewModel.step = .verificationCode
                }
            }
        case .verificationFailure, .verificationTimeout, .failure:
            Button("확인", role: .cancel) {}
        case .existingAccount:
            Button("다른 번호로 인증") {
                withAnimation {
                    viewModel.retryWithAnotherNumber()
                }
            }
            Button("로그인하러 가기") {
                viewModel.discardTempAccountAndReturn()
            }
        case .phoneNumberInUse:
            Button("확인") {
                withAnimation {
                    viewModel.step = .phoneNumber
                }
            }
        case .sessionExpired:
            Button("확인") {
                viewModel.discardTempAccountAndReturn()
            }
        case .confirmCancel:
            Button("계속 입력", role: .cancel) {}
            Button("가입 취소", role: .destructive) {
                viewModel.discardTempAccountAndReturn()
            }
        case .loginFailed:
            Button("다시 시도") {
                loginViewModel.completeSocialSignUp()
            }
        }
    }
}

private extension SocialSignUpAlert {
    var title: String {
        switch self {
        case .codeSent: return "인증번호 전송"
        case .verificationFailure: return "인증 실패"
        case .verificationTimeout: return "시간 만료"
        case .existingAccount: return "이미 가입된 계정"
        case .phoneNumberInUse: return "사용 중인 번호"
        case .sessionExpired: return "가입 시간 만료"
        case .failure: return "회원가입 실패"
        case .confirmCancel: return "가입을 취소할까요?"
        case .loginFailed: return "로그인 실패"
        }
    }

    var message: String {
        switch self {
        case .codeSent: return "인증번호가 전송되었습니다."
        case .verificationFailure: return "인증번호가 일치하지 않습니다."
        case .verificationTimeout: return "인증 시간이 만료되었습니다. 인증번호를 다시 요청해주세요."
        case .existingAccount(let message): return message
        case .phoneNumberInUse: return "이미 사용 중인 번호입니다. 잠시 후 다시 시도하거나 다른 번호를 입력해주세요."
        case .sessionExpired: return "가입 시간이 만료되었습니다. 다시 시도해주세요."
        case .failure(let message): return message
        case .confirmCancel: return "입력한 정보는 저장되지 않으며 로그인 화면으로 돌아갑니다."
        case .loginFailed(let message): return message
        }
    }
}

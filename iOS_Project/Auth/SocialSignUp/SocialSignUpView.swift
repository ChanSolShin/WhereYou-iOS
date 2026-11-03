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
    @State private var showCancelConfirm = false
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
        .alert(item: $viewModel.alert) { alert in
            alertView(for: alert)
        }
        .alert("가입을 취소할까요?", isPresented: $showCancelConfirm) {
            Button("계속 입력", role: .cancel) {}
            Button("가입 취소", role: .destructive) {
                viewModel.discardTempAccountAndReturn()
            }
        } message: {
            Text("입력한 정보는 저장되지 않으며 로그인 화면으로 돌아갑니다.")
        }
        // 가입 완료 후 세션 확립 실패 시 (users 문서는 저장된 상태라 재시도만)
        .alert("로그인 실패", isPresented: Binding(
            get: { loginViewModel.currentAlert != nil },
            set: { if !$0 { loginViewModel.currentAlert = nil } }
        )) {
            Button("다시 시도") {
                loginViewModel.completeSocialSignUp()
            }
        } message: {
            if case .loginFailed(let message) = loginViewModel.currentAlert {
                Text(message)
            } else {
                Text("로그인에 실패했습니다. 다시 시도해주세요.")
            }
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
                    showCancelConfirm = true
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

    private func alertView(for alert: SocialSignUpAlert) -> Alert {
        switch alert {
        case .codeSent:
            return Alert(
                title: Text("인증번호 전송"),
                message: Text("인증번호가 전송되었습니다."),
                dismissButton: .default(Text("확인")) {
                    withAnimation {
                        viewModel.step = .verificationCode
                    }
                }
            )
        case .verificationFailure:
            return Alert(
                title: Text("인증 실패"),
                message: Text("인증번호가 일치하지 않습니다."),
                dismissButton: .default(Text("확인"))
            )
        case .verificationTimeout:
            return Alert(
                title: Text("시간 만료"),
                message: Text("인증 시간이 만료되었습니다. 인증번호를 다시 요청해주세요."),
                dismissButton: .default(Text("확인"))
            )
        case .existingAccount(let message):
            return Alert(
                title: Text("이미 가입된 계정"),
                message: Text(message),
                dismissButton: .default(Text("로그인하러 가기")) {
                    viewModel.discardTempAccountAndReturn()
                }
            )
        case .phoneNumberInUse:
            return Alert(
                title: Text("사용 중인 번호"),
                message: Text("이미 사용 중인 번호입니다. 잠시 후 다시 시도하거나 다른 번호를 입력해주세요."),
                dismissButton: .default(Text("확인")) {
                    withAnimation {
                        viewModel.step = .phoneNumber
                    }
                }
            )
        case .sessionExpired:
            return Alert(
                title: Text("가입 시간 만료"),
                message: Text("가입 시간이 만료되었습니다. 다시 시도해주세요."),
                dismissButton: .default(Text("확인")) {
                    viewModel.discardTempAccountAndReturn()
                }
            )
        case .failure(let message):
            return Alert(
                title: Text("회원가입 실패"),
                message: Text(message),
                dismissButton: .default(Text("확인"))
            )
        }
    }
}

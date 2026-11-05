//
//  SocialSignUpViewModel.swift
//  iOS_Project
//
//  Created by 최용훈 on 03/11/26.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// 소셜 회원가입 단계 (연락처 인증을 먼저 해서 기존 계정 여부를 가장 빨리 안내)
enum SocialSignUpStep: Int, CaseIterable {
    case phoneNumber
    case verificationCode
    case name
    case birthday
    case email
    case terms
}

enum SocialSignUpAlert: Identifiable {
    case codeSent
    case verificationFailure
    case verificationTimeout
    case existingAccount(String)    // 이미 가입된 번호 → 기존 계정 로그인 안내 후 로그인 화면으로
    case phoneNumberInUse           // 사용 중인 번호지만 가입 정보 확인 불가 → 다른 번호 입력
    case sessionExpired             // 임시 계정 만료 → 로그인 화면으로
    case failure(String)
    case confirmCancel              // 가입 취소 확인
    case loginFailed(String)        // 가입 완료 후 세션 확립 실패 → 재시도

    var id: String {
        switch self {
        case .codeSent: return "codeSent"
        case .verificationFailure: return "verificationFailure"
        case .verificationTimeout: return "verificationTimeout"
        case .existingAccount: return "existingAccount"
        case .phoneNumberInUse: return "phoneNumberInUse"
        case .sessionExpired: return "sessionExpired"
        case .failure: return "failure"
        case .confirmCancel: return "confirmCancel"
        case .loginFailed: return "loginFailed"
        }
    }
}

// 소셜 회원가입 결과 (화면에서 LoginViewModel로 전달)
enum SocialSignUpResult {
    case completed       // users 문서 저장 완료 → 세션 확립 후 메인
    case returnToLogin   // 취소/기존 계정 안내/만료 → 로그아웃 후 로그인 화면
}

final class SocialSignUpViewModel: ObservableObject {
    @Published var step: SocialSignUpStep = .phoneNumber

    // 입력값
    @Published var name: String = ""
    @Published var wantsToInputBirthday = false
    @Published var birthday: String = ""
    @Published var email: String = ""
    @Published var phoneNumber: String = ""
    @Published var selectedCountry: CountryCode?
    @Published var verificationCode: String = ""
    @Published var agreedToTerms = false

    // 전화번호 인증
    @Published var isPhoneVerified = false
    @Published var timerValue: Int = 300
    @Published var isTimerActive = false

    @Published var emailErrorMessage: String?
    @Published var isLoading = false
    @Published var alert: SocialSignUpAlert?
    @Published var result: SocialSignUpResult?

    let countryCodes = loadCountryCodes()

    private let db = Firestore.firestore()
    private var verificationID: String?
    private var timer: AnyCancellable?

    init() {
        prefillFromSocialAccount()
    }

    // 소셜 계정 정보로 미리 채우기 (Apple 이름은 SocialAuthManager에서 displayName에 저장)
    // Apple 이메일 가리기(privaterelay) 주소는 친구 검색에 쓸 수 없어 비워 둠
    private func prefillFromSocialAccount() {
        guard let user = Auth.auth().currentUser else { return }
        name = user.displayName ?? ""
        if let socialEmail = user.email, !socialEmail.hasSuffix("@privaterelay.appleid.com") {
            email = socialEmail
        }
    }

    // MARK: - 다음 단계 가능 여부

    var canProceed: Bool {
        switch step {
        case .phoneNumber:
            return isPhoneVerified  // 인증 전에는 인증번호 전송으로만 진행
        case .verificationCode:
            return isPhoneVerified
        case .name:
            return NameInputStep.isValid(name)
        case .birthday:
            return BirthdayPickerStep.isValid(wantsToInput: wantsToInputBirthday, birthday: birthday)
        case .email:
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedEmail.isEmpty || Self.isValidEmail(trimmedEmail)
        case .terms:
            return agreedToTerms
        }
    }

    func goBack() {
        guard let previous = SocialSignUpStep(rawValue: step.rawValue - 1) else { return }
        // 인증 완료 후에는 인증번호 단계를 건너뛰고 휴대전화 단계로
        step = (previous == .verificationCode && isPhoneVerified) ? .phoneNumber : previous
    }

    func goNext() {
        switch step {
        case .phoneNumber:
            // 이미 인증한 뒤 뒤로 돌아온 경우
            if isPhoneVerified { step = .name }
        case .email:
            validateEmailAvailability { [weak self] isAvailable in
                if isAvailable { self?.step = .terms }
            }
        case .terms:
            completeSignUp()
        default:
            if let next = SocialSignUpStep(rawValue: step.rawValue + 1) {
                step = next
            }
        }
    }

    // MARK: - 전화번호 인증 (SMS 인증 후 현재 소셜 계정에 link)

    func sendVerificationCode() {
        guard let countryCode = selectedCountry?.code else { return }
        isLoading = true
        PhoneAuthProvider.provider().verifyPhoneNumber(countryCode + phoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                print("[SocialSignUp] Verification code send failed (code: \((error as NSError).code))")
                self.alert = .failure("인증번호를 보내지 못했습니다. 잠시 후 다시 시도해주세요.")
                return
            }
            self.verificationID = verificationID
            self.verificationCode = ""
            self.startTimer()
            self.alert = .codeSent
        }
    }

    func verifyCode() {
        guard let verificationID = verificationID, let user = Auth.auth().currentUser else {
            alert = .sessionExpired
            return
        }
        guard timerValue > 0 else {
            alert = .verificationTimeout
            return
        }

        isLoading = true
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        user.link(with: credential) { [weak self] _, error in
            guard let self = self else { return }
            guard let error = error else {
                self.isLoading = false
                self.markPhoneVerified()
                return
            }

            let code = AuthErrorCode(rawValue: (error as NSError).code)
            switch code {
            case .providerAlreadyLinked:
                // 뒤로 갔다가 다시 인증한 경우 이미 연결된 상태
                self.isLoading = false
                self.markPhoneVerified()
            case .credentialAlreadyInUse:
                // 이미 다른 계정에 연결된 번호 → 기존 계정 안내
                self.handleExistingPhoneNumber()
            case .invalidVerificationCode:
                self.isLoading = false
                self.alert = .verificationFailure
            case .sessionExpired:
                self.isLoading = false
                self.verificationID = nil
                self.alert = .verificationTimeout
            case .userNotFound, .userTokenExpired, .invalidUserToken, .userDisabled:
                self.isLoading = false
                self.alert = .sessionExpired
            default:
                print("[SocialSignUp] Phone link failed (code: \((error as NSError).code))")
                self.isLoading = false
                self.alert = .failure("인증에 실패했습니다. 잠시 후 다시 시도해주세요.")
            }
        }
    }

    func resendCode() {
        sendVerificationCode()
    }

    private func markPhoneVerified() {
        isPhoneVerified = true
        isTimerActive = false
        timer?.cancel()
        step = .name
    }

    private func startTimer() {
        timer?.cancel()
        timerValue = 300 // 5분
        isTimerActive = true
        timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            if self.timerValue > 0 {
                self.timerValue -= 1
            } else {
                self.isTimerActive = false
                self.timer?.cancel()
            }
        }
    }

    // MARK: - 기존 계정 안내 (SMS 인증으로 번호 소유가 확인된 뒤에만 표시)

    private var formattedPhoneNumber: String {
        PhoneNumberStep.formatted(phoneNumber, countryCode: selectedCountry?.code ?? "")
    }

    private func handleExistingPhoneNumber() {
        db.collection("users").whereField("phoneNumber", isEqualTo: formattedPhoneNumber).limit(to: 1).getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            guard let data = snapshot?.documents.first?.data() else {
                // 가입 도중인 다른 임시 계정 등 users 문서가 없는 경우
                self.alert = .phoneNumberInUse
                return
            }
            self.alert = .existingAccount(Self.existingAccountMessage(for: data))
        }
    }

    // 기존 계정의 로그인 수단별 안내 문구
    // providers가 없는 기존 계정은 모두 이메일 가입이므로 이메일 로그인 안내
    static func existingAccountMessage(for data: [String: Any]) -> String {
        let providers = data["providers"] as? [String] ?? []
        if providers.isEmpty || providers.contains("password") {
            let loginEmail = data["loginEmail"] as? String ?? data["email"] as? String ?? ""
            return "\(maskedEmail(loginEmail)) 으로 가입된 계정이 있어요.\n이메일로 로그인해 주세요."
        }
        if let provider = SocialAuthProvider.allCases.first(where: { providers.contains($0.providerID) }) {
            return "\(provider.displayName)로 가입된 계정이 있어요.\n\(provider.displayName)로 로그인해 주세요."
        }
        return "이미 가입된 계정이 있어요.\n기존 계정으로 로그인해 주세요."
    }

    // ab***@naver.com (아이디 앞 2글자만 표시)
    static func maskedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1)
        guard parts.count == 2 else { return "***" }
        let visibleCount = parts[0].count > 2 ? 2 : 1
        return "\(parts[0].prefix(visibleCount))***@\(parts[1])"
    }

    // MARK: - 이메일 (선택 입력, 입력 시 형식 + 중복 검사)

    private static func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }

    private func validateEmailAvailability(completion: @escaping (Bool) -> Void) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        emailErrorMessage = nil
        guard !trimmedEmail.isEmpty else {
            completion(true)
            return
        }

        isLoading = true
        db.collection("users").whereField("email", isEqualTo: trimmedEmail).limit(to: 1).getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                print("[SocialSignUp] Email check failed (code: \((error as NSError).code))")
                self.emailErrorMessage = "이메일 확인 중 오류가 발생했습니다. 다시 시도해주세요."
                completion(false)
                return
            }
            if snapshot?.isEmpty == false {
                self.emailErrorMessage = "이미 사용 중인 이메일이에요. 다른 이메일을 입력하거나 비워 두세요."
                completion(false)
                return
            }
            self.email = trimmedEmail
            completion(true)
        }
    }

    // MARK: - 가입 완료 (users 문서 저장)

    private func completeSignUp() {
        guard isPhoneVerified, agreedToTerms, let user = Auth.auth().currentUser else {
            alert = .sessionExpired
            return
        }

        var userData: [String: Any] = [
            "name": name.trimmingCharacters(in: .whitespacesAndNewlines),
            "phoneNumber": formattedPhoneNumber,
            "loginStatus": false,
            "createdAt": Timestamp(date: Date())
        ]
        if !email.isEmpty {
            userData["email"] = email
        }
        if wantsToInputBirthday, !birthday.isEmpty {
            userData["birthday"] = birthday
        }
        // 로그인 수단 (google.com/apple.com, phone)
        userData.merge(UserAuthInfo.fields(for: user)) { _, new in new }

        isLoading = true
        let uid = user.uid
        db.collection("users").document(uid).setData(userData) { [weak self] error in
            guard let self = self else { return }
            self.isLoading = false
            if let error = error {
                print("[SocialSignUp] User document save failed (code: \((error as NSError).code))")
                // 임시 계정이 정리된 경우 권한 오류로 실패
                if (error as NSError).code == FirestoreErrorCode.permissionDenied.rawValue
                    || (error as NSError).code == FirestoreErrorCode.unauthenticated.rawValue {
                    self.alert = .sessionExpired
                } else {
                    self.alert = .failure("회원가입에 실패했습니다. 잠시 후 다시 시도해주세요.")
                }
                return
            }
            self.db.collection("tempUsers").document(uid).delete()
            self.result = .completed
        }
    }

    // MARK: - 가입 취소 / 기존 계정 안내 후 이동

    // 임시 소셜 계정 삭제(서버) 후 로그인 화면으로
    // 삭제에 실패해도 tempUsers 정리(Functions)에서 일정 시간 후 삭제
    func discardTempAccountAndReturn() {
        timer?.cancel()
        isLoading = true
        TempAccountService.discard { [weak self] in
            self?.isLoading = false
            self?.result = .returnToLogin
        }
    }
}

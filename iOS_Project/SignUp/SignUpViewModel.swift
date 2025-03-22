//
//  SignUpViewModel.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/11/24.
//

import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

class SignUpViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var realName: String = ""
    @Published var birthday: String = ""
    @Published var phoneNumber: String = ""
    @Published var verificationCode: String = ""
    @Published var signUpErrorMessage: String?
    @Published var signUpErrorMessageColor: Color = .red
    @Published var signUpSuccess: Bool = false
    
    // 전화번호 인증 관련
    @Published var verificationID: String?
    @Published var isVerificationCodeSent: Bool = false
    @Published var isVerificationSuccessful: Bool = false
    @Published var timerValue: Int = 300 // 5분
    @Published var isTimerActive: Bool = false
    @Published var isVerificationUIEnabled: Bool = true  // 인증 성공 후 버튼, 타이머 제어
    @Published var showAlertType: SignUpActiveAlert? = nil
    
    // 에러 메시지 변수
    @Published var phoneVerificationErrorMessage: String? = nil  // 전화번호 인증 관련
    @Published var emailVerificationErrorMessage: String? = nil  // 이메일 확인 관련
    @Published var generalErrorMessage: String? = nil            // 기타(회원가입 실패 등)
    
    private var timer: AnyCancellable?
    private var db = Firestore.firestore()
    
    var selectedCountryCode: String = ""
    
    // Credential 저장 변수
    private var phoneAuthCredential: PhoneAuthCredential?
    
    
    var successCreate: Bool {
        return username.isEmpty || !isValidEmail || password.count < 6 || confirmPassword.isEmpty || !passwordMatches || realName.isEmpty || birthday.count != 8 || phoneNumber.count != 11
    }
    
    var passwordMatches: Bool {
        return !confirmPassword.isEmpty && password == confirmPassword
    }
    
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: username)
    }
    
    func checkEmailAvailability(completion: @escaping (Bool) -> Void) {
        db.collection("users").whereField("email", isEqualTo: username).getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error checking email availability: \(error.localizedDescription)")
                completion(false)
                return
            }
            if let snapshot = querySnapshot, snapshot.isEmpty {
                completion(true)
            } else {
                completion(false)
            }
        }
    }
    
    func signUp() {
        signUpErrorMessage = nil
        
        // 전화번호 인증 후 생성 된 임시계정에 입력한 이메일/비밀번호를 link
        guard let currentUser = Auth.auth().currentUser else {
            self.signUpErrorMessage = "전화번호 인증을 완료해주세요."
            self.signUpSuccess = false
            self.showAlertType = .signUpFailure
            return
        }
        
        let emailCredential = EmailAuthProvider.credential(withEmail: username, password: password)
        
        currentUser.link(with: emailCredential) { [weak self] authResult, error in
            if let error = error {
                if let errCode = AuthErrorCode(rawValue: error._code) {
                    switch errCode {
                    case .emailAlreadyInUse:
                        self?.emailVerificationErrorMessage = "이미 가입된 이메일입니다."
                    default:
                        self?.signUpErrorMessage = error.localizedDescription
                    }
                }
                self?.signUpSuccess = false
                self?.showAlertType = .signUpFailure
                return
            }
            
            guard let user = authResult?.user else {
                self?.signUpErrorMessage = "사용자 정보를 가져올 수 없습니다."
                self?.signUpSuccess = false
                self?.showAlertType = .signUpFailure
                return
            }
            
            print("이메일 연결 성공")
            self?.saveUserDataToFirestore(uid: user.uid)
        }
    }
    
    private func saveUserDataToFirestore(uid: String) {
        // 전화번호 형식 변환 후 저장
        let formattedPhone = formatPhoneNumber(phoneNumber)
        let userData: [String: Any] = [
            "email": username,
            "name": realName,
            "phoneNumber": formattedPhone,
            "birthday": birthday,
            "loginStatus": false,                  // 로그인 여부
            "createdAt": Timestamp(date: Date())  // 회원가입 날짜
        ]
        
        db.collection("users").document(uid).setData(userData) { [weak self] error in
            if let error = error {
                print("Firestore 저장 오류: \(error.localizedDescription)")
                self?.signUpErrorMessage = "Firestore 저장 오류: \(error.localizedDescription)"
                self?.signUpSuccess = false
            } else {
                print("Firestore 저장 성공")
                self?.signUpSuccess = true
            }
        }
    }
    
    // MARK: - 전화번호 인증 요청
    func sendVerificationCode(fullPhoneNumber: String) {
        self.signUpErrorMessage = nil
        self.isVerificationCodeSent = false
        self.isVerificationSuccessful = false
        self.isVerificationUIEnabled = true  // 재시도 시 버튼 활성화
        
        let formattedPhone = formatPhoneNumber(phoneNumber)
        
        // Firestore에서 전화번호 중복 확인 추가
        db.collection("users").whereField("phoneNumber", isEqualTo: formattedPhone).getDocuments { [weak self] snapshot, error in
            if let error = error {
                print("전화번호 중복 확인 에러: \(error.localizedDescription)")
                self?.signUpErrorMessage = "전화번호 중복 확인 중 오류가 발생했습니다."
                return
            }
            if let snapshot = snapshot, !snapshot.isEmpty {
                print("이미 가입된 전화번호")
                self?.phoneVerificationErrorMessage = "이미 가입된 전화번호입니다."
                return
            }
            // 인증번호 발송 진행
            PhoneAuthProvider.provider().verifyPhoneNumber(fullPhoneNumber, uiDelegate: nil) { [weak self] verificationID, error in
                if let error = error {
                    print("전화번호 인증 에러: \(error.localizedDescription)")
                    self?.signUpErrorMessage = error.localizedDescription
                    return
                }
                print("인증번호 발송 성공, verificationID: \(verificationID ?? "")")
                self?.verificationID = verificationID
                self?.isVerificationCodeSent = true
                self?.startTimer()
            }
        }
    }
    
    // MARK: - 타이머 시작
    func startTimer() {
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
    
    // MARK: - 인증번호 확인
    func verifyCode() {
        guard let verificationID = verificationID else { return }

        // 인증번호 입력 여부 확인
        if verificationCode.isEmpty {
            self.signUpErrorMessage = "인증번호를 입력해주세요."
            DispatchQueue.main.async {
                self.showAlertType = .emptyVerificationCode
            }
            return
        }

        // 타이머 만료 여부 확인
        if timerValue == 0 {
            self.signUpErrorMessage = "인증 시간이 만료되었습니다."
            DispatchQueue.main.async {
                self.showAlertType = .verificationTimeout
            }
            self.verificationID = nil
            return
        }
        
        // Credential 생성
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        // Firebase 서버에 유효성 확인
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            guard let self = self else { return }

            if let error = error {
                let errorCode = (error as NSError).code
                print("인증 실패 오류 코드: \(errorCode), 메시지: \(error.localizedDescription)")

                if let authError = AuthErrorCode(rawValue: errorCode) {
                    switch authError {
                    case .invalidVerificationCode:
                        self.phoneVerificationErrorMessage = "인증번호가 일치하지 않습니다."
                        self.showAlertType = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                self.showAlertType = .verificationFailure
                            }
                        
                    case .sessionExpired:
                        self.phoneVerificationErrorMessage = "인증번호가 만료되었습니다. 다시 요청해주세요."
                        self.showAlertType = .verificationTimeout
                        self.verificationID = nil
                    default:
                        self.phoneVerificationErrorMessage = "알 수 없는 오류가 발생했습니다."
                    }
                }
                return
            }
            
            // 인증 성공 처리
            print("전화번호 인증 성공, Credential 저장됨")
            self.phoneAuthCredential = credential  // 이후 회원가입 시 link용
            self.isVerificationSuccessful = true   // 인증 성공 표시
            self.isVerificationUIEnabled = false   // 인증 버튼 비활성화
            self.isTimerActive = false             // 타이머 멈춤
            self.timer?.cancel()
            
        }
    }
    
    // MARK: - 재전송
    func resendCode(fullPhoneNumber: String) {
        sendVerificationCode(fullPhoneNumber: fullPhoneNumber)
    }
    
    // MARK: - Helper: 전화번호 형식 변환 (선택된 국가코드 기준)
    private func formatPhoneNumber(_ number: String) -> String {
        // +82: 010으로 시작할 경우 10으로 시작하도록 변환
        if selectedCountryCode == "+82" {
            var digits = number
            if digits.hasPrefix("0") {
                digits = String(digits.dropFirst())
            }
            return selectedCountryCode + digits
        } else {
            if number.hasPrefix("+") {
                return number
            }
            return selectedCountryCode + number
        }
    }
}

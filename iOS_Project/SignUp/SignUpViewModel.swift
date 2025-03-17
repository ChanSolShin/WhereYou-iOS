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
        
        Auth.auth().createUser(withEmail: username, password: password) { [weak self] authResult, error in
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
                return
            }
            
            guard let user = authResult?.user else {
                self?.signUpErrorMessage = "사용자 정보를 가져올 수 없습니다."
                return
            }
            
            // Firestore에 사용자 정보 저장
            // 전화번호 Credential 연결
            if let credential = self?.phoneAuthCredential {
                user.link(with: credential) { result, error in
                    if let error = error {
                        print("전화번호 연결 실패: \(error.localizedDescription)")
                        self?.signUpErrorMessage = "전화번호 연결 실패: \(error.localizedDescription)"
                        return
                    }
                    print("전화번호 연결 성공")
                    self?.saveUserDataToFirestore(uid: user.uid)
                }
            } else {
                // 전화번호 인증이 되지 않았다면 에러 처리
                self?.signUpErrorMessage = "전화번호 인증을 완료해주세요."
                self?.signUpSuccess = false
            }
        }
    }
    
    private func saveUserDataToFirestore(uid: String) {
        let userData: [String: Any] = [
            "email": username,
            "name": realName,
            "phoneNumber": phoneNumber,
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
        
        // Firestore에서 전화번호 중복 확인 추가
        db.collection("users").whereField("phoneNumber", isEqualTo: phoneNumber).getDocuments { [weak self] snapshot, error in
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
            return
        }
        
        // Credential 생성
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        // 실제로 인증번호가 맞는지 Firebase 인증 서버에 요청
        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                print("인증번호 불일치: \(error.localizedDescription)")
                self?.phoneVerificationErrorMessage = "인증번호가 일치하지 않습니다."
                DispatchQueue.main.async {
                    self?.showAlertType = .verificationFailure  // 인증 실패 알림
                }
                return
            }
            
            // 인증 성공 처리
            print("전화번호 인증 성공, Credential 저장됨")
            self?.phoneAuthCredential = credential  // 이후 회원가입 시 link용
            self?.isVerificationSuccessful = true   // 인증 성공 표시
            self?.isVerificationUIEnabled = false   // 인증 버튼 비활성화
            self?.isTimerActive = false             // 타이머 멈춤
            self?.timer?.cancel()
            
        }
    }
    
    // MARK: - 재전송
    func resendCode(fullPhoneNumber: String) {
        sendVerificationCode(fullPhoneNumber: fullPhoneNumber)
    }
}

import SwiftUI
import FirebaseAuth

class FindPasswordViewModel: ObservableObject {
    @Published var model = FindPasswordModel(email: "")
    @Published var errorMessage: String?
    
    // 이메일 형식 유효성 검사
    private var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegEx)
        return emailTest.evaluate(with: model.email)
    }
    
    func resetPassword(completion: @escaping () -> Void) {
        // 이메일 필드가 비어 있는지 확인
        guard !model.email.isEmpty else {
            errorMessage = "이메일을 입력해 주세요."
            completion()
            return
        }
        
        // 이메일 형식이 유효한지 확인
        guard isValidEmail else {
            errorMessage = "올바른 이메일 형식으로 입력해 주세요."
            completion()
            return
        }
        
        // Firebase 비밀번호 재설정 요청
        Auth.auth().sendPasswordReset(withEmail: model.email) { [weak self] error in
                self?.errorMessage = nil // 에러 메시지는 설정하지 않음
                completion()
            
        }
    }
}

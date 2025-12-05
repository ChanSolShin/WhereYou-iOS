import SwiftUI

// 키보드 활성화 시, 올라가는 필드 여백 값 조정
struct KeyboardAvoidingModifier: ViewModifier {
    var offsetValue: CGFloat // 여백 값
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear {
                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillShowNotification,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        withAnimation {
                            self.keyboardHeight = keyboardFrame.height - offsetValue
                        }
                    }
                }

                NotificationCenter.default.addObserver(
                    forName: UIResponder.keyboardWillHideNotification,
                    object: nil,
                    queue: .main
                ) { _ in
                    withAnimation {
                        self.keyboardHeight = 0
                    }
                }
            }
    }
}

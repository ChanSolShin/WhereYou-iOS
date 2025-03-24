//
//  EditProfileView.swift
//  iOS_Project
//
//  Created by CHOI on 11/5/24.
//

import SwiftUI

enum ActiveAlert: Identifiable {
    case delete, validation, back
    var id: Int {
        switch self {
        case .delete: return 1
        case .validation: return 2
        case .back: return 3
        }
    }
}

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var activeAlert: ActiveAlert? = nil
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var birthday = ""

    // 유효성 검사 실패 시 Alert 관련 상태 변수 추가
    @State private var validationAlertMessage = ""

    enum Field: Hashable {
        case name, email, phone, birthday
    }
    @FocusState private var focusedField: Field?

    // 키보드 활성화 여부 감지 변수
    @State private var isKeyboardVisible = false
    @State private var showDeleteButton = true // 탈퇴하기 버튼을 보여줄지 여부

    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    Text("내 정보 수정")
                        .font(.title2)
                        .bold()
                        .padding(.top, 20)

                    Divider()

                    Group {
                        Text("이름")
                            .font(.title3)
                        TextField("이름", text: $name)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.done)
                    }
                    Group {
                        Text("생년월일 (YYDDMM)")
                            .font(.title3)
                        TextField("생일", text: $birthday)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .birthday)
                    }

                    Group {
                        Text("이메일")
                            .font(.title3)
                        TextField("이메일", text: $email)
                            .disabled(true)
                            .padding()
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(10)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.done)
                    }

                    Group {
                        Text("연락처")
                            .font(.title3)
                        TextField("전화번호", text: $phoneNumber)
                            .disabled(true)
                            .padding()
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(10)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .phone)
                    }

                    

                    Spacer(minLength: 50) // 입력 필드와 하단 버튼 간 여백 확보
                }
                .padding()
                .onTapGesture {
                    focusedField = nil // 화면을 터치하면 키보드 내려감
                }
            }

            Spacer() // 버튼을 항상 하단에 고정

            // 키보드가 내려간 후 버튼이 보이도록 함
            if showDeleteButton {
                Button(action: {
                    activeAlert = .delete
                }) {
                    Text("탈퇴하기")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .delete:
                return Alert(
                    title: Text("정말로 탈퇴하시겠습니까?"),
                    message: Text("계정이 영구적으로 삭제됩니다."),
                    primaryButton: .destructive(Text("탈퇴"), action: {
                        viewModel.deleteAccount()
                    }),
                    secondaryButton: .cancel(Text("취소"))
                )
            case .validation:
                return Alert(
                    title: Text("입력 형식을 확인해주세요"),
                    message: Text(validationAlertMessage),
                    dismissButton: .default(Text("확인"))
                )
            case .back:
                return Alert(
                    title: Text("수정사항이 있습니다."),
                    message: Text("저장하지 않고 나가시겠습니까?"),
                    primaryButton: .destructive(Text("나가기"), action: {
                        presentationMode.wrappedValue.dismiss()
                    }),
                    secondaryButton: .cancel(Text("취소"))
                )
            }
        }
        .onAppear {
            name = viewModel.profile?.name ?? ""
            email = viewModel.profile?.email ?? ""
            phoneNumber = viewModel.profile?.phoneNumber ?? ""
            birthday = viewModel.profile?.birthday ?? ""

            // 키보드 상태 감지 설정
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                isKeyboardVisible = true
                showDeleteButton = false // 키보드가 올라가면 버튼 숨김
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                isKeyboardVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showDeleteButton = true // 키보드가 완전히 내려간 후 버튼 표시
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .fullScreenCover(isPresented: $viewModel.navigateToLogin) {
            LoginView() // 회원탈퇴 후 로그인 화면으로 이동
        }
        .navigationBarBackButtonHidden(true) // 기본 뒤로가기 버튼 숨김
        .navigationBarItems(
            leading: Button(action: {
                // 변경사항이 있는지 확인
                if let profile = viewModel.profile,
                   name == profile.name,
                   email == profile.email,
                   phoneNumber == profile.phoneNumber,
                   birthday == profile.birthday {
                    // 변경사항 없음 -> 바로 뒤로가기
                    presentationMode.wrappedValue.dismiss()
                } else {
                    // 변경사항 있음 -> 알림 표시
                    activeAlert = .back
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("뒤로")
                }
            },
            trailing: Button("완료") {
                focusedField = nil // 완료 버튼을 누르면 키보드 내려감
                if viewModel.updateProfileData(newName: name, newEmail: email, newPhoneNumber: phoneNumber, newBirthday: birthday) {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    validationAlertMessage = viewModel.errorMessage ?? "입력한 정보를 다시 확인해주세요."
                    activeAlert = .validation
                }
            }
        )
    }
}

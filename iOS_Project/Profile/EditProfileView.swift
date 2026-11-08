//
//  EditProfileView.swift
//  iOS_Project
//
//  Created by CHOI on 11/5/24.
//

import SwiftUI

struct EditProfileView: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var birthday = ""
    
    // 유효성 검사 실패 시 Alert 메시지
    @State private var validationAlertMessage = ""
    
    // 탈퇴 관련 상태 변수: 커스텀 PasswordAlertView 표시 여부
    @State private var showPasswordAlert = false

    enum Field: Hashable {
        case name, email, phone, birthday
    }
    @FocusState private var focusedField: Field?
    
    // 키보드 활성화 감지
    @State private var isKeyboardVisible = false
    @State private var showDeleteButton = true // 탈퇴하기 버튼 표시 여부
    @State private var showBirthdayPicker = false

    // 생년월일 표시 (변환할 수 없는 기존 값은 다시 선택 안내)
    private var birthdayDisplayText: String {
        guard !birthday.isEmpty else { return "입력 안 함" }
        guard let date = BirthdayWheelPicker.date(from: birthday) else {
            return "\(birthday) (다시 선택해 주세요)"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월 d일"
        return formatter.string(from: date)
    }

    // 탈퇴 확인 문구 (본인 확인 방식 안내)
    private var deleteConfirmMessage: String {
        switch viewModel.withdrawalReauth {
        case .social(let provider):
            return "계정이 영구적으로 삭제됩니다.\n본인 확인을 위해 \(provider.displayName) 로그인을 한 번 더 진행합니다."
        case .password, nil:
            return "계정이 영구적으로 삭제됩니다."
        }
    }

    // 로그인 수단에 맞는 재인증 후 탈퇴
    private func startWithdrawal() {
        switch viewModel.withdrawalReauth {
        case .password:
            showPasswordAlert = true
        case .social(let provider):
            // 확인 알림이 닫힌 뒤 로그인 창 표시 (닫히는 중인 알림 위에는 Google 로그인 화면을 띄울 수 없음)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                viewModel.reauthenticateWithSocialAndDelete(provider)
            }
        case nil:
            viewModel.showDeleteFailure("로그인 정보를 확인하지 못했습니다. 다시 로그인한 뒤 시도해주세요.")
        }
    }

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
                            .glassSurface(radius: 10)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.done)
                    }
                    Group {
                        Text("생년월일")
                            .font(.title3)
                        Button(action: {
                            focusedField = nil
                            withAnimation {
                                showBirthdayPicker.toggle()
                            }
                        }) {
                            HStack {
                                Text(birthdayDisplayText)
                                    .foregroundColor(birthday.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: showBirthdayPicker ? "chevron.up" : "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .glassSurface(radius: 10)
                        }
                        if showBirthdayPicker {
                            BirthdayWheelPicker(birthday: $birthday)
                                .frame(maxWidth: .infinity)
                            if !birthday.isEmpty {
                                Button("생년월일 지우기") {
                                    birthday = ""
                                    withAnimation {
                                        showBirthdayPicker = false
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                            }
                        }
                    }

                    Group {
                        Text("이메일")
                            .font(.title3)
                        TextField("이메일", text: $email)
                            .disabled(!viewModel.canEditEmail)
                            .foregroundColor(viewModel.canEditEmail ? .primary : .gray)
                            .autocapitalization(.none)
                            .padding()
                            .glassSurface(radius: 10)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.done)
                        Text(viewModel.canEditEmail
                             ? "친구가 이메일로 나를 찾을 때 사용됩니다. 비워 둘 수 있습니다."
                             : "로그인 이메일은 변경할 수 없습니다.")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Group {
                        Text("연락처")
                            .font(.title3)
                        TextField("전화번호", text: $phoneNumber)
                            .disabled(true)
                            .padding()
                            .glassSurface(radius: 10)
                            .keyboardType(.numberPad)
                            .focused($focusedField, equals: .phone)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding()
                .onTapGesture {
                    focusedField = nil
                }
            }
            
            Spacer()
            
            // 키보드가 내려간 후 탈퇴하기 버튼 표시
            if showDeleteButton {
                Button(action: {
                    viewModel.activeAlert = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        viewModel.activeAlert = .delete
                    }
                }) {
                    Text("탈퇴하기")
                        .foregroundColor(.red)
                        .padding()
                }
            }
        }
        .background(GlassBackdrop())
        .onAppear {
            name = viewModel.profile?.name ?? ""
            email = viewModel.profile?.email ?? ""
            phoneNumber = viewModel.profile?.phoneNumber ?? ""
            birthday = viewModel.profile?.birthday ?? ""
            
            // 키보드 상태 감지
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { _ in
                isKeyboardVisible = true
                showDeleteButton = false
            }
            NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                isKeyboardVisible = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    showDeleteButton = true
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self)
        }
        .fullScreenCover(isPresented: $viewModel.navigateToLogin) {
            LoginView()
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {
                // 뒤로 버튼: 변경사항 없으면 바로 뒤로, 있으면 경고
                if let profile = viewModel.profile,
                   name == profile.name,
                   email == profile.email,
                   phoneNumber == profile.phoneNumber,
                   birthday == profile.birthday {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    viewModel.activeAlert = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        viewModel.activeAlert = .back
                    }
                }
            }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("뒤로")
                }
            },
            trailing: Button("완료") {
                focusedField = nil
                viewModel.updateProfileData(newName: name, newEmail: email, newBirthday: birthday) { success in
                    if success {
                        presentationMode.wrappedValue.dismiss()
                    } else {
                        validationAlertMessage = viewModel.errorMessage ?? "입력한 정보를 다시 확인해주세요."
                        viewModel.activeAlert = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            viewModel.activeAlert = .validation
                        }
                    }
                }
            }
        )
        .overlay(
            Group {
                if showPasswordAlert {
                    PasswordAlertView(isPresented: $showPasswordAlert) { password in
                        // 비밀번호 입력 후 재인증 및 탈퇴 진행
                        viewModel.reauthenticateAndDelete(password: password)
                    }
                }
                if viewModel.isProcessing {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        )
        .alert(item: $viewModel.activeAlert) { alert in
            switch alert {
            case .delete:
                return Alert(
                    title: Text("정말로 탈퇴하시겠습니까?"),
                    message: Text(deleteConfirmMessage),
                    primaryButton: .destructive(Text("탈퇴"), action: startWithdrawal),
                    secondaryButton: .cancel(Text("취소"))
                )
            case .deleteFailed:
                return Alert(
                    title: Text("탈퇴 실패"),
                    message: Text(viewModel.errorMessage ?? "탈퇴 처리 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요."),
                    dismissButton: .default(Text("확인"))
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
            case .passwordError:
                return Alert(
                    title: Text("비밀번호 오류"),
                    message: Text("비밀번호가 일치하지 않습니다."),
                    dismissButton: .default(Text("확인"))
                )
            }
        }
    }
}

// MARK: - 커스텀 PasswordAlertView

struct PasswordAlertView: View {
    @Binding var isPresented: Bool
    var onConfirm: (String) -> Void
    
    @State private var password: String = ""
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Text("비밀번호 입력")
                    .font(.headline)
                
                SecureField("비밀번호", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("취소")
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: {
                        isPresented = false
                        onConfirm(password)
                    }) {
                        Text("확인")
                            .foregroundColor(.blue)
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal, 40)
        }
    }
}

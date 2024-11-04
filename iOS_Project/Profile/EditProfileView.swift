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
    @State private var showDeleteAlert = false
    @State private var showAlert = false
    @State private var name = ""
    @State private var email = ""
    @State private var phoneNumber = ""
    @State private var birthday = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("내 정보 수정")
                .font(.title2)
                .bold()
                .padding(.top, 20)
            
            Divider()
            
            Text("이름")
                .font(.title3)
            TextField("이름", text: $name)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            
            Text("이메일")
                .font(.title3)
            TextField("이메일", text: $email)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            
            Text("연락처")
                .font(.title3)
            TextField("전화번호", text: $phoneNumber)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .keyboardType(.numberPad)
            
            Text("생년월일 (YYDDMM)")
                .font(.title3)
            TextField("생일", text: $birthday)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
                .keyboardType(.numberPad)
            
            Spacer()
            
            HStack {
                Spacer()
                Button(action: {
                    showDeleteAlert = true
                }) {
                    Text("탈퇴하기")
                        .foregroundColor(.red)
                }
                .alert(isPresented: $showDeleteAlert) {
                    Alert(
                        title: Text("정말로 탈퇴하시겠습니까?"),
                        message: Text("계정이 영구적으로 삭제됩니다."),
                        primaryButton: .destructive(Text("탈퇴"), action: {
                            viewModel.deleteAccount()
                            presentationMode.wrappedValue.dismiss()
                        }),
                        secondaryButton: .cancel(Text("취소"))
                    )
                }
                Spacer()
            }
        }
        .padding()
        .onAppear {
            name = viewModel.profile?.name ?? ""
            email = viewModel.profile?.email ?? ""
            phoneNumber = viewModel.profile?.phoneNumber ?? ""
            birthday = viewModel.profile?.birthday ?? ""
        }
        
        .navigationBarItems(
            trailing: Button("완료") {
                if viewModel.updateProfileData(newName: name, newEmail: email, newPhoneNumber: phoneNumber, newBirthday: birthday) {
                    presentationMode.wrappedValue.dismiss()
                } else {
                    showAlert = true
                }
            }
        )
        .alert(isPresented: $showAlert) {
            Alert(title: Text("입력 오류"), message: Text(viewModel.errorMessage ?? "알 수 없는 오류"), dismissButton: .default(Text("확인")))
        }
    }
}


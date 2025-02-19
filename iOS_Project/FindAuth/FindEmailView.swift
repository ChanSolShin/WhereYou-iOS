//
//  FindEmailView.swift
//  iOS_Project
//
//  Created by CHOI on 10/31/24.
//
import SwiftUI

struct FindEmailView: View {
    @StateObject private var viewModel = FindEmailViewModel()
    @State private var showAlert = false
    
    var body: some View {
        ScrollView{
            VStack {
                Text("웨어유")
                    .font(.largeTitle)
                    .padding(.top, 20)
                    .padding(.bottom, 60)
                    .fontWeight(.bold)
                
                
                VStack {
                    HStack{
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("이름을 입력하세요", text: $viewModel.model.name)
                        
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom,10)
                    
                    HStack{
                        Image(systemName: "calendar")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("생년월일(8자리)", text: $viewModel.model.birthday)
                            .keyboardType(.numberPad)
                            .onChange(of: viewModel.model.birthday) { newValue in
                                if newValue.count > 8 {
                                    viewModel.model.birthday = String(newValue.prefix(8))
                                }
                            }
                            .font(.system(size: 16))
                        
                    }.padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.bottom,10)
                    
                    HStack{
                        Image(systemName: "phone")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                        TextField("전화번호를 입력하세요 ( - 없이 )", text:$viewModel.model.phoneNumber)
                            .keyboardType(.numberPad)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.bottom,20)
                    
                    Button(action: {
                        viewModel.findEmail { success in
                            showAlert = !success
                        }
                    }) {
                        Text("이메일 찾기")
                            .frame(width: 200, height: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding(.bottom,10)
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("알림"), message: Text(viewModel.errorMessage ?? "일치하는 계정이 없습니다."))
                    }
                    
                    if let foundEmail = viewModel.foundEmail {
                        Text("사용 중인 이메일: \(foundEmail)")
                            .foregroundColor(.blue)
                            .padding()
                    }
                    Spacer()
                }
            }
            .navigationTitle("이메일 찾기")
        }
        
    }
}

import SwiftUI

struct AddFriendNumberModal: View {
    @ObservedObject var viewModel: FriendListViewModel
    @Binding var isPresented: Bool
    @State private var phoneNumber: String = ""
    @State private var countryCodes: [CountryCode] = []
    @State private var selectedCountry: CountryCode? = nil

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Text("추가할 친구의 전화번호를 입력해 주세요")

                HStack(spacing: 20) {
                    Menu {
                        ForEach(countryCodes, id: \.id) { code in
                            Button(action: {
                                selectedCountry = code
                            }) {
                                Text("\(code.emoji) \(code.country) (\(code.code))")
                            }
                        }
                    } label: {
                        if let selected = selectedCountry {
                            Text("\(selected.emoji) \(selected.country) (\(selected.code))")
                                .font(.system(size: 14))
                        } else {
                            Text("선택 ⬇️")
                                .font(.system(size: 14))
                        }
                    }
                    .frame(width: 130)

                    TextField("전화번호", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }

                Button(action: {
                    guard let selected = selectedCountry else { return }
                    var cleanPhone = phoneNumber.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                    if cleanPhone.hasPrefix("0") {
                        cleanPhone.removeFirst()
                    }
                    let fullPhone = selected.code + cleanPhone
                    viewModel.sendFriendRequest(toPhoneNumber: fullPhone)
                    isPresented = false
                }) {
                    Text("친구 요청 보내기")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((phoneNumber.isEmpty || selectedCountry == nil) ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(phoneNumber.isEmpty || selectedCountry == nil)
                .padding(.horizontal)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .padding()
        .onAppear {
            countryCodes = loadCountryCodes().reversed()
        }
    }
}

//
//  AddLocationView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//

import SwiftUI
import CoreLocation

struct AddLocationView: View {
    @ObservedObject var viewModel: AddMeetingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    
    var body: some View {
        VStack {
            Text("원하는 장소를 터치해주세요")
                .padding(.top, 10)
                .font(.headline)
                .fontWeight(.bold)
            TextField("장소 검색", text: $searchQuery)
                .font(.body)
                .padding(.vertical, 10)
                .padding(.horizontal, 6)
                .background(Color(.systemGray6))
                .cornerRadius(3)
                .padding(.horizontal)
                .onChange(of: searchQuery) { newValue in
                    viewModel.fetchSearchResults(query: newValue) { results in
                        DispatchQueue.main.async {
                            self.searchResults = results
                        }
                    }
                }

            if !searchResults.isEmpty {
                List(searchResults, id: \.address) { result in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(result.title)
                            .font(.subheadline)
                        Text(result.address)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    .onTapGesture {
                        let address = result.address
                        viewModel.meeting.meetingAddress = address
                        viewModel.geocode(address: address) { coordinate in
                            DispatchQueue.main.async {
                                self.selectedLocation = coordinate
                            }
                        }
                        searchResults = []
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                .frame(height: 200)
                .listStyle(PlainListStyle())
            }

            ZStack(alignment: .bottomTrailing) {
                MapView(isMarkerEnabled: true, viewModel: viewModel, selectedLocation: $selectedLocation)
                    .navigationBarHidden(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .edgesIgnoringSafeArea(.all)
                VStack {
                    Text(viewModel.meeting.meetingAddress ?? "지정 된 장소 없음")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .fontWeight(.bold)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(5)

                    HStack {
                        Button("선택") {
                            presentationMode.wrappedValue.dismiss()
                        }
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 100, height: 50)
                        .background(Color.blue)
                        .cornerRadius(30)
                        .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

extension String {
    var htmlDecoded: String {
        let data = Data(utf8)
        guard let attributedString = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            ) else {
            return self
        }
        return attributedString.string
    }
}

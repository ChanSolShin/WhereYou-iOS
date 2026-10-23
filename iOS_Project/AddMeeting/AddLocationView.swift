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
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchQuery: String = ""
    @State private var searchResults: [SearchResult] = []
    @State private var selectedLocation: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("검색하거나 지도에서 원하는 장소를 터치해 주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                TextField("장소 검색", text: $searchQuery)
                    .font(.body)
                    .padding(12)
                    .glassSurface(radius: 12)
                    .padding(.horizontal, 16)
                    .onChange(of: searchQuery) { newValue in
                        viewModel.fetchSearchResults(query: newValue) { results in
                            DispatchQueue.main.async {
                                searchResults = results
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
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            let address = result.address
                            viewModel.meeting.meetingAddress = address
                            viewModel.geocode(address: address) { coordinate in
                                DispatchQueue.main.async {
                                    selectedLocation = coordinate
                                }
                            }
                            searchResults = []
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .frame(height: 180)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                MapView(isMarkerEnabled: true, viewModel: viewModel, selectedLocation: $selectedLocation)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text(viewModel.meeting.meetingAddress ?? "지정 된 장소 없음")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .glassSurface(radius: 12)

                    Button {
                        dismiss()
                    } label: {
                        Text("이 장소 선택").frame(maxWidth: .infinity)
                    }
                    .glassPrimaryAction()
                    .controlSize(.large)
                    .disabled(viewModel.meeting.meetingAddress == nil)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GlassBackdrop())
            }
            .background(GlassBackdrop())
            .navigationTitle("장소 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

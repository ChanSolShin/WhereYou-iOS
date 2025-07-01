//
//  AddLocationView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//

import SwiftUI
import NMapsMap
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
                    fetchSearchResults()
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
                        geocode(address: address)
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
    
    func fetchSearchResults() {
        guard !searchQuery.isEmpty,
              let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://openapi.naver.com/v1/search/local.json?query=\(encodedQuery)&display=5&start=1&sort=random") else { return }

        var request = URLRequest(url: url)
        request.setValue("fZX8IYa_kpXrzkGHZRQE", forHTTPHeaderField: "X-Naver-Client-Id")
        request.setValue("u8jU2QKWqS", forHTTPHeaderField: "X-Naver-Client-Secret")

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data {
                do {
                    let decoded = try JSONDecoder().decode(NaverLocalSearchResponse.self, from: data)
                    if let json = String(data: data, encoding: .utf8) {
                        print("📦 API 응답 JSON: \(json)")
                    }
                    let results = decoded.items ?? []
                    DispatchQueue.main.async {
                        searchResults = results.map {
                            SearchResult(
                                title: $0.title.htmlDecoded,
                                address: !$0.roadAddress.isEmpty ? $0.roadAddress : $0.address,
                                coordinate: convertTM128ToWGS84(
                                    x: Double($0.mapx) ?? 0,
                                    y: Double($0.mapy) ?? 0
                                )
                            )
                        }
                    }
                } catch {
                    print("디코딩 실패: \(error)")
                }
            } else if let error = error {
                print("네트워크 오류: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    func geocode(address: String) {
        let cleanedAddress = address.components(separatedBy: "(").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? address
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(cleanedAddress) { placemarks, error in
            if let error = error {
                print("주소 변환 실패: \(error.localizedDescription)")
                return
            }
            
            if let location = placemarks?.first?.location {
                selectedLocation = location.coordinate
                print("변환된 좌표: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            } else {
                if let selected = searchResults.first(where: { $0.address == address }) {
                    selectedLocation = selected.coordinate
                    print("네이버 좌표 fallback: \(selected.coordinate.latitude), \(selected.coordinate.longitude)")
                } else {
                    print("좌표를 찾을 수 없습니다.")
                }
            }
        }
    }
    
    func convertTM128ToWGS84(x: Double, y: Double) -> CLLocationCoordinate2D {
        let lon = (x - 1000000.0) / 5.0 / 3600.0 + 127.5
        let lat = (y - 2000000.0) / 5.0 / 3600.0 + 38.0
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

struct SearchResult {
    let title: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

struct NaverLocalSearchResponse: Decodable {
    let items: [NaverLocalItem]?

    enum CodingKeys: String, CodingKey {
        case items
    }
}

struct NaverLocalItem: Decodable {
    let title: String
    let mapx: String
    let mapy: String
    let address: String
    let roadAddress: String
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

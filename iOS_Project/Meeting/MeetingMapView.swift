//
//  MeetingMapView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//
import SwiftUI
import NMapsMap
import CoreLocation

struct MeetingMapView: View {
    var meeting: MeetingModel // MeetingModel을 사용하여 미팅 정보를 받아옴

    var body: some View {
        VStack {
            NaverMapView(coordinate: meeting.meetingLocation, title: meeting.title, address: meeting.meetingAddress) // 미팅의 좌표, 제목 및 주소를 넘겨줌
                .edgesIgnoringSafeArea(.all)
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NaverMapView: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D // 지도에 표시할 좌표
    var title: String // 미팅 제목
    var address: String? // 미팅 주소

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)

        // 초기 카메라 위치 설정
        let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
        naverMapView.mapView.moveCamera(cameraUpdate)

        // 현재 위치 버튼 표시
        naverMapView.showLocationButton = true

        // Custom Marker 추가
        addCustomMarker(to: naverMapView, coordinate: coordinate)

        return naverMapView
    }

    func addCustomMarker(to naverMapView: NMFNaverMapView, coordinate: CLLocationCoordinate2D) {
        // Custom Marker를 위한 SwiftUI View 생성
        let infoWindowView = InfoWindowView(name: title, address: address)
        
        // UIHostingController를 사용하여 SwiftUI View를 UIView로 변환
        let controller = UIHostingController(rootView: infoWindowView)
        controller.view.frame = CGRect(origin: .zero, size: CGSize(width: 240, height: 110))
        controller.view.backgroundColor = .clear

        if let rootVC = UIApplication.shared.windows.first?.rootViewController {
            rootVC.view.insertSubview(controller.view, at: 0)

            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 240, height: 125))
            let infoWindowImage = renderer.image { context in
                controller.view.layer.render(in: context.cgContext)
            }

            let marker = NMFMarker()
            marker.position = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
            marker.iconImage = NMFOverlayImage(image: infoWindowImage)
            marker.mapView = naverMapView.mapView
            marker.touchHandler = { _ in
                // 마커 터치 이벤트 핸들링
                return true
            }

            // SwiftUI View 제거
            controller.view.removeFromSuperview()
        }
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        // UIView 업데이트 로직
    }
}

struct InfoWindowView: View {
    var name: String
    var address: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Text(address ?? "")
                    .font(.custom("NotoSansCJKr-Regular", size: 13))
                    .lineLimit(1)
            }
            .padding(.top, 10)
            .padding(.bottom, 17)
            .padding(.horizontal, 17)
            .background(AddressBubble())
            .padding(.bottom, 5)

            Image("ic_position_marker") // 마커 이미지
        }
    }
}

// 말풍선 뷰
struct AddressBubble: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(lineWidth: 1)
                    .background(Color.white)
                    .cornerRadius(12)
                
                Spacer()
            }
            
            Triangle()
                .stroke(lineWidth: 1)
                .frame(width: 12, height: 8)
                .background(Color.white)
                .clipShape(Triangle())
            
            Rectangle()
                .frame(width: 10.5, height: 2)
                .foregroundColor(.white)
                .padding(.bottom, 7.5)
        }
    }
    
    struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            return path
        }
    }
}

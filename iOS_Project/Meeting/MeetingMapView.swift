//
//  MeetingMapView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/23/24.
//
import SwiftUI
import NMapsMap
import CoreLocation
import FirebaseDatabase

struct MeetingMapView: View {
    @Binding var selectedUserLocation: CLLocationCoordinate2D?
    var meeting: MeetingModel // MeetingModel을 사용하여 미팅 정보를 받아옴
    
    var body: some View {
        VStack {
            // NaverMapView에 selectedUserLocation을 바인딩으로 전달
            NaverMapView(
                coordinate: $selectedUserLocation,
                title: meeting.title, address: meeting.meetingAddress
            )
            .edgesIgnoringSafeArea(.all) // 미팅의 좌표, 제목 및 주소를 넘겨줌
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedUserLocation) { newLocation in
            if let location = newLocation {
                print("Camera moving to selected user location: \(location.latitude), \(location.longitude)")
            } else {
                print("Selected user location is nil, reverting to meeting location")
            }
        }
    }
}

struct NaverMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    var title: String
    var address: String?
    
    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)
        
        // 초기 카메라 위치 설정
        if let initialCoordinate = coordinate {
            moveCamera(to: initialCoordinate, in: naverMapView)
        }
        
        naverMapView.showLocationButton = true
        
        // 커스텀 마커 추가
        if let initialCoordinate = coordinate {
            addCustomMarker(to: naverMapView, coordinate: initialCoordinate)
        }
        
        return naverMapView
    }
    
    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        if let newCoordinate = coordinate {
            print("Moving camera to coordinates in updateUIView: \(newCoordinate.latitude), \(newCoordinate.longitude)")
            moveCamera(to: newCoordinate, in: uiView)
        } else {
            print("Coordinate is nil in updateUIView, no camera update")
        }
    }
    
    private func moveCamera(to coordinate: CLLocationCoordinate2D, in mapView: NMFNaverMapView) {
        let cameraPosition = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
        let cameraUpdate = NMFCameraUpdate(scrollTo: cameraPosition, zoomTo: 16)
        cameraUpdate.animation = .fly
        cameraUpdate.animationDuration = 1.5
        mapView.mapView.moveCamera(cameraUpdate)
    }
    
    func addCustomMarker(to naverMapView: NMFNaverMapView, coordinate: CLLocationCoordinate2D) {
        let infoWindowView = InfoWindowView(name: title, address: address)
        
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
                return true
            }
            
            // SwiftUI View 제거
            controller.view.removeFromSuperview()
        }
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

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}


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
                meeting: meeting
            )
            .edgesIgnoringSafeArea(.all) // 미팅의 좌표, 제목 및 주소를 넘겨줌
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NaverMapView: UIViewRepresentable {
    @Binding var coordinate: CLLocationCoordinate2D?
    var meeting: MeetingModel
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)
        naverMapView.showLocationButton = true
        
        // 초기 카메라 위치 설정 (모임 장소로)
        moveCamera(to: meeting.meetingLocation, in: naverMapView)
        
        // 모임 장소 마커 추가
        context.coordinator.addMeetingMarker(to: naverMapView)
        
        return naverMapView
    }
    
    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        guard let newCoordinate = coordinate else { return }
        
        // 카메라 이동
        moveCamera(to: newCoordinate, in: uiView)
        
        // 마커 업데이트
        if newCoordinate == meeting.meetingLocation {
            // 모임 장소로 이동할 경우, 선택된 멤버 마커 제거
            context.coordinator.removeMemberMarker()
        } else {
            // 멤버 위치로 이동할 경우, 선택된 멤버 마커 추가 또는 업데이트
            context.coordinator.updateMemberMarker(to: newCoordinate, in: uiView)
        }
    }
    
    private func moveCamera(to coordinate: CLLocationCoordinate2D, in mapView: NMFNaverMapView) {
        let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
        cameraUpdate.animation = .fly
        cameraUpdate.animationDuration = 1.5
        mapView.mapView.moveCamera(cameraUpdate)
    }
    
    class Coordinator: NSObject {
        var parent: NaverMapView
        var meetingMarker: NMFMarker?
        var memberMarker: NMFMarker?
        
        init(_ parent: NaverMapView) {
            self.parent = parent
        }
        
        func addMeetingMarker(to mapView: NMFNaverMapView) {
            let meetingCoordinate = parent.meeting.meetingLocation
            let infoWindowView = InfoWindowView(name: parent.meeting.title, address: parent.meeting.meetingAddress)
            
            let controller = UIHostingController(rootView: infoWindowView)
            controller.view.frame = CGRect(origin: .zero, size: CGSize(width: 240, height: 125))
            controller.view.backgroundColor = .clear
            
            // 캡처된 이미지로 마커 아이콘 생성
            if let rootVC = UIApplication.shared.windows.first?.rootViewController {
                rootVC.view.insertSubview(controller.view, at: 0)
                
                let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
                let infoWindowImage = renderer.image { _ in
                    controller.view.layer.render(in: UIGraphicsGetCurrentContext()!)
                }
                
                let marker = NMFMarker()
                marker.position = NMGLatLng(lat: meetingCoordinate.latitude, lng: meetingCoordinate.longitude)
                marker.iconImage = NMFOverlayImage(image: infoWindowImage)
                marker.mapView = mapView.mapView
                marker.touchHandler = { _ in
                    return true
                }
                
                self.meetingMarker = marker
                
                // SwiftUI View 제거
                controller.view.removeFromSuperview()
            }
        }
        
        func updateMemberMarker(to coordinate: CLLocationCoordinate2D, in mapView: NMFNaverMapView) {
            if memberMarker == nil {
                // 멤버 마커가 없으면 새로 생성
                let marker = NMFMarker()
                marker.position = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
                marker.iconImage = NMF_MARKER_IMAGE_BLUE // 기본 마커 이미지 사용
                marker.mapView = mapView.mapView
                self.memberMarker = marker
            } else {
                // 이미 존재하면 위치 업데이트
                memberMarker?.position = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
            }
        }
        
        func removeMemberMarker() {
            memberMarker?.mapView = nil
            memberMarker = nil
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

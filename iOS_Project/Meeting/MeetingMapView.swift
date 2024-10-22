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
            NaverMapView(coordinate: meeting.meetingLocation) // 미팅의 좌표를 넘겨줌
                .edgesIgnoringSafeArea(.all)
        }
        .navigationTitle(meeting.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct NaverMapView: UIViewRepresentable {
    var coordinate: CLLocationCoordinate2D // 지도에 표시할 좌표

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = NMFNaverMapView(frame: .zero)

        // 초기 카메라 위치 설정
        let cameraUpdate = NMFCameraUpdate(scrollTo: NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude))
        naverMapView.mapView.moveCamera(cameraUpdate)

        // 현재 위치 버튼 표시
        naverMapView.showLocationButton = true

        // 마커 추가
        let marker = NMFMarker()
        marker.position = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
        marker.mapView = naverMapView.mapView
        marker.iconImage = NMF_MARKER_IMAGE_BLUE

        return naverMapView
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        // UIView 업데이트 로직
    }
}

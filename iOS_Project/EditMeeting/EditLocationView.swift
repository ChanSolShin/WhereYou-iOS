//
//  EditLocationView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 11/7/24.
//

import SwiftUI
import NMapsMap
import FirebaseFirestore

struct EditLocationView: View {
    @ObservedObject var viewModel: EditMeetingViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Text("원하는 장소를 터치하여 수정해주세요")
            .padding(.top, 10)
            .font(.headline)
            .fontWeight(.bold)
        
        ZStack(alignment: .bottomTrailing) {
            EditMapView(isMarkerEnabled: true, viewModel: viewModel)
                .navigationBarHidden(true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Text(viewModel.meetingAddress)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fontWeight(.bold)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                
                HStack {
                    Button("확인") {
                        // 선택 완료 후 이전 화면으로 돌아가기
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

struct EditMapView: View {
    var isMarkerEnabled: Bool
    @ObservedObject var viewModel: EditMeetingViewModel
    @StateObject private var coordinator: EditCoordinator
    
    init(isMarkerEnabled: Bool, viewModel: EditMeetingViewModel) {
        self.isMarkerEnabled = isMarkerEnabled
        self.viewModel = viewModel
        _coordinator = StateObject(wrappedValue: EditCoordinator(viewModel: viewModel))
    }
    
    var body: some View {
        VStack {
            EditNaverMap(coordinator: coordinator, isMarkerEnabled: isMarkerEnabled, viewModel: viewModel)
        }
    }
}

struct EditNaverMap: UIViewRepresentable {
    @ObservedObject var coordinator: EditCoordinator
    var isMarkerEnabled: Bool
    @ObservedObject var viewModel: EditMeetingViewModel
    
    func makeCoordinator() -> EditCoordinator {
        coordinator
    }
    
    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = context.coordinator.getNaverMapView()
        
        // 초기 위치 설정: 기존 meetingLocation에 맞춰 카메라 이동
        let initialLocation = NMGLatLng(lat: viewModel.meetingLocation.latitude, lng: viewModel.meetingLocation.longitude)
        naverMapView.mapView.moveCamera(NMFCameraUpdate(scrollTo: initialLocation))
        
        // 기존 위치에 마커 추가
        let initialMarker = NMFMarker()
        initialMarker.position = initialLocation
        initialMarker.iconImage = NMF_MARKER_IMAGE_GREEN
        initialMarker.mapView = naverMapView.mapView
        initialMarker.anchor = CGPoint(x: 0.5, y: 1.0)
        
        naverMapView.mapView.touchDelegate = context.coordinator
        return naverMapView
    }
    
    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {}
}

final class EditCoordinator: NSObject, ObservableObject, NMFMapViewCameraDelegate, NMFMapViewTouchDelegate {
    var editMeetingViewModel: EditMeetingViewModel
    let view = NMFNaverMapView(frame: .zero)
    var currentMarker: NMFMarker?
    
    init(viewModel: EditMeetingViewModel) {
        self.editMeetingViewModel = viewModel
        super.init()
        setupMapView()
    }
    
    private func setupMapView() {
        view.mapView.positionMode = .direction
        view.mapView.isNightModeEnabled = true
        view.mapView.zoomLevel = 15
        view.mapView.minZoomLevel = 5
        view.mapView.maxZoomLevel = 18
        view.showLocationButton = true
        view.showZoomControls = true
    }

    func mapView(_ mapView: NMFMapView, didTapMap coord: NMGLatLng, point: CGPoint) {
        // 기존 마커 제거
        currentMarker?.mapView = nil
        
        // 새로운 마커 추가
        let marker = NMFMarker()
        marker.position = coord
        marker.iconImage = NMF_MARKER_IMAGE_BLUE
        marker.mapView = mapView
        marker.anchor = CGPoint(x: 0.5, y: 1.0)
        currentMarker = marker
        
        // 선택된 좌표로 주소 변환
        reverseGeocodeCoordinate(CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng))
    }

    private func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { (placemarks, error) in
            if let error = error {
                print("주소 변환 오류: \(error)")
                return
            }
            guard let placemark = placemarks?.first else {
                print("주소를 찾을 수 없습니다.")
                return
            }
            var addressComponents: [String] = []
            
            if let locality = placemark.locality { addressComponents.append(locality) }
            if let thoroughfare = placemark.thoroughfare { addressComponents.append(thoroughfare) }
            if let subThoroughfare = placemark.subThoroughfare { addressComponents.append(subThoroughfare) }
            
            let fullAddress = addressComponents.joined(separator: " ")
            
            // CLLocationCoordinate2D를 GeoPoint로 변환하여 업데이트
            let geoPoint = GeoPoint(latitude: coordinate.latitude, longitude: coordinate.longitude)
            self.editMeetingViewModel.meetingLocation = geoPoint
            self.editMeetingViewModel.meetingAddress = fullAddress
        }
    }

    func getNaverMapView() -> NMFNaverMapView {
        return view
    }
}

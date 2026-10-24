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
    @Environment(\.dismiss) private var dismiss
    @State private var showAlert: Bool = false
    @State private var alertMessage: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("지도에서 원하는 장소를 터치해 주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                EditMapView(isMarkerEnabled: true, viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 16)
            }
            .padding(.top, 12)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text(viewModel.meetingAddress)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .glassSurface(radius: 12)

                    Button { dismiss() } label: {
                        Text("이 장소 선택").frame(maxWidth: .infinity)
                    }
                        .glassPrimaryAction()
                        .controlSize(.large)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(GlassBackdrop())
            }
            .background(GlassBackdrop())
            .navigationTitle("장소 수정")
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

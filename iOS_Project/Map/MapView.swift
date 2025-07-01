//
//  MapView.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//


import SwiftUI
import NMapsMap
import CoreLocation

struct MapView: View {
    var isMarkerEnabled: Bool // 마커 추가 기능을 활성화하는 변수
    @ObservedObject var viewModel: AddMeetingViewModel // ViewModel 추가
    @Binding var selectedLocation: CLLocationCoordinate2D?

    @StateObject private var coordinator: Coordinator

    init(isMarkerEnabled: Bool, viewModel: AddMeetingViewModel, selectedLocation: Binding<CLLocationCoordinate2D?>) {
        self.isMarkerEnabled = isMarkerEnabled
        self.viewModel = viewModel
        self._selectedLocation = selectedLocation
        self._coordinator = StateObject(wrappedValue: Coordinator(viewModel: viewModel, selectedLocation: selectedLocation))
    }

    var body: some View {
        VStack {
            NaverMap(coordinator: coordinator, isMarkerEnabled: isMarkerEnabled, viewModel: viewModel, selectedLocation: $selectedLocation)
        }
    }
}

struct NaverMap: UIViewRepresentable {
    @ObservedObject var coordinator: Coordinator
    var isMarkerEnabled: Bool
    @ObservedObject var viewModel: AddMeetingViewModel // ViewModel 추가
    @Binding var selectedLocation: CLLocationCoordinate2D?

    func makeCoordinator() -> Coordinator {
        coordinator
    }

    
    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = context.coordinator.getNaverMapView()
        naverMapView.mapView.touchDelegate = context.coordinator
        naverMapView.mapView.addCameraDelegate(delegate: context.coordinator)
        naverMapView.mapView.addOptionDelegate(delegate: context.coordinator)
        return naverMapView
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {
        if let location = selectedLocation {
            if coordinator.currentMarker == nil || coordinator.currentMarker?.position.lat != location.latitude || coordinator.currentMarker?.position.lng != location.longitude {
                coordinator.addMarkerAndMove(to: location, with: viewModel.meeting.meetingAddress ?? "선택된 장소")
            }
        }
    }
}

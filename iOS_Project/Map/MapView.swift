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

    @StateObject private var coordinator: Coordinator

    init(isMarkerEnabled: Bool, viewModel: AddMeetingViewModel) {
        self.isMarkerEnabled = isMarkerEnabled
        self.viewModel = viewModel
        _coordinator = StateObject(wrappedValue: Coordinator(viewModel: viewModel)) // ViewModel 
    }

    var body: some View {
        VStack {
            NaverMap(coordinator: coordinator, isMarkerEnabled: isMarkerEnabled, viewModel: viewModel)
        }
    }
}

struct NaverMap: UIViewRepresentable {
    @ObservedObject var coordinator: Coordinator
    var isMarkerEnabled: Bool
    @ObservedObject var viewModel: AddMeetingViewModel // ViewModel 추가

    func makeCoordinator() -> Coordinator {
        coordinator
    }

    func makeUIView(context: Context) -> NMFNaverMapView {
        let naverMapView = context.coordinator.getNaverMapView()
        naverMapView.mapView.touchDelegate = context.coordinator
        naverMapView.mapView.addCameraDelegate(delegate: context.coordinator)
        naverMapView.mapView.addOptionDelegate(delegate: context.coordinator)

        if isMarkerEnabled {
            naverMapView.mapView.touchDelegate = context.coordinator
        } else {
            naverMapView.mapView.touchDelegate = nil
        }

        return naverMapView
    }

    func updateUIView(_ uiView: NMFNaverMapView, context: Context) {}
}

//
//  Coordinator.swift
//  iOS_Project
//
//  Created by 신찬솔 on 10/19/24.
//
import NMapsMap
import Combine
import CoreLocation
import SwiftUI


final class Coordinator: NSObject, ObservableObject, NMFMapViewCameraDelegate, NMFMapViewTouchDelegate, NMFMapViewOptionDelegate {
    // Coordinator가 AddMeetingViewModel을 직접 받을 수 있도록 생성자를 수정
    var addMeetingViewModel: AddMeetingViewModel
    @Binding var selectedLocation: CLLocationCoordinate2D?
    
    let view = NMFNaverMapView(frame: .zero)
    var currentMarker: NMFMarker?
    
    init(viewModel: AddMeetingViewModel, selectedLocation: Binding<CLLocationCoordinate2D?>) {
        self.addMeetingViewModel = viewModel
        self._selectedLocation = selectedLocation
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
        view.showCompass = false
        view.showScaleBar = false
        
        view.mapView.addCameraDelegate(delegate: self)
        view.mapView.touchDelegate = self
        view.mapView.addOptionDelegate(delegate: self)
    }

    // MARK: - 터치 이벤트 처리 (지도에서 터치 시 마커 추가)
    func mapView(_ mapView: NMFMapView, didTapMap coord: NMGLatLng, point: CGPoint) {
        // 기존 마커 제거
        currentMarker?.mapView = nil

        // 새로운 마커 생성
        let marker = NMFMarker()
        marker.position = coord
        marker.iconImage = NMF_MARKER_IMAGE_BLUE
        marker.anchor = CGPoint(x: 0.5, y: 1.0)
        marker.width = 30
        marker.height = 50

        // 현재 마커 저장 및 지도에 추가
        currentMarker = marker
        marker.mapView = mapView

        // 주소 초기화
        addMeetingViewModel.meeting.meetingAddress = nil

        // ViewModel에 위치 정보 즉시 반영
        let newCoordinate = CLLocationCoordinate2D(latitude: coord.lat, longitude: coord.lng)
        addMeetingViewModel.meeting.meetingLocation = newCoordinate
        self.selectedLocation = newCoordinate

        // 주소 정보 가져오기
        reverseGeocodeCoordinate(newCoordinate)
        
        
    }

    // MARK: - 좌표에서 주소 정보 가져오기
    func reverseGeocodeCoordinate(_ coordinate: CLLocationCoordinate2D) {
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
            
            
            if let locality = placemark.locality {
                addressComponents.append(locality) // 시
            }
            
            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare) // 도로명 주소
            }
            
            if let subThoroughfare = placemark.subThoroughfare {
                addressComponents.append(subThoroughfare) // 번지
            }
            
            
            let fullAddress = addressComponents.joined(separator: " ")
            print("주소: \(fullAddress)")
            
            // ViewModel에 위치 정보 업데이트
            DispatchQueue.main.async {
                self.addMeetingViewModel.meeting.meetingAddress = fullAddress
                print("Updated Meeting Address: \(String(describing: self.addMeetingViewModel.meeting.meetingAddress))")
            }
        }
    }

    func getNaverMapView() -> NMFNaverMapView {
        return view
    }
    
    // MARK: - 마커 추가 및 카메라 이동
    func addMarkerAndMove(to coordinate: CLLocationCoordinate2D, with title: String) {
        DispatchQueue.main.async {
            // 기존 마커 제거
            self.currentMarker?.mapView = nil

            // 새로운 마커 생성
            let marker = NMFMarker()
            marker.position = NMGLatLng(lat: coordinate.latitude, lng: coordinate.longitude)
            marker.iconImage = NMF_MARKER_IMAGE_BLUE
            marker.anchor = CGPoint(x: 0.5, y: 1.0)
            marker.width = 30
            marker.height = 50

            self.currentMarker = marker
            marker.mapView = self.view.mapView

            // 카메라 이동
            let cameraUpdate = NMFCameraUpdate(scrollTo: marker.position)
            cameraUpdate.animation = .easeIn
            self.view.mapView.moveCamera(cameraUpdate)

            // ViewModel 업데이트
            self.addMeetingViewModel.meeting.meetingLocation = coordinate

            // 주소 변환
            self.reverseGeocodeCoordinate(coordinate)
        }
    }
    
    func checkIfLocationServiceIsEnabled() {
        DispatchQueue.global().async {
            if CLLocationManager.locationServicesEnabled() {
                DispatchQueue.main.async {
                    print("위치 서비스 활성화됨")
                }
            } else {
                print("위치 서비스가 비활성화되었습니다.")
            }
        }
    }
}

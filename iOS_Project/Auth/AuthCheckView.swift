//
//  AuthCheckView.swift
//  iOS_Project
//
//  Created by 최용훈 on 31/10/26.
//

import SwiftUI

// 앱 시작 스플래시 겸 사용자 정보 확인 중 / 확인 실패 화면
// 런치 스크린(Info.plist UILaunchScreen)과 같은 배경색, 같은 위치의 로고로 이어지도록 구성
struct AuthCheckView: View {
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var showsLaunchBackground = true
    @State private var showsProgress = false  // 1초 넘게 걸릴 때만 로딩 표시 (일반 실행 시 로고만)

    var body: some View {
        ZStack(alignment: Alignment(horizontal: .center, vertical: .logoCenter)) {
            GlassBackdrop()

            // 런치 스크린 배경색에서 앱 배경으로 서서히 전환
            Color("LaunchBackground")
                .opacity(showsLaunchBackground ? 1 : 0)
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                // 로고 중심을 화면 정중앙에 고정 (런치 스크린 로고와 같은 위치, 같은 크기)
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 100)
                    .alignmentGuide(.logoCenter) { $0[VerticalAlignment.center] }

                if loginViewModel.authState == .checkFailed {
                    Text("사용자 정보를 불러오지 못했습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)

                    Button(action: {
                        loginViewModel.retryAutoLoginCheck()
                    }) {
                        Text("다시 시도")
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .fontWeight(.bold)
                            .cornerRadius(40)
                    }
                    .padding(.horizontal, 30)
                } else {
                    // 표시 여부와 관계없이 자리를 유지해 로딩 표시가 나타날 때 로고가 움직이지 않도록 함
                    ProgressView()
                        .opacity(showsProgress ? 1 : 0)
                        .accessibilityLabel("사용자 정보 확인 중")
                        .accessibilityHidden(!showsProgress)
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                showsLaunchBackground = false
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeIn(duration: 0.2)) {
                showsProgress = true
            }
        }
    }
}

private extension VerticalAlignment {
    // 로고 중심 정렬 기준 (기본값: 화면 중앙)
    enum LogoCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let logoCenter = VerticalAlignment(LogoCenter.self)
}

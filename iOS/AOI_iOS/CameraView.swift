//
//  CameraView.swift
//  MultiCamiOS
//
//  Created by ZSS on 2025/8/6.
//

import SwiftUI
import AVFoundation

struct CameraView: View {

    @StateObject private var cameraMgr = CameraManager.shared
    private let connector = MacConnector.shared

    @State private var isAuthorized = false
    @State private var selectedID: Int = 1
    @State private var selectedLens: CameraManager.LensMode = .wide

    var body: some View {
        ZStack {
            if isAuthorized {
                CameraPreviewView(session: cameraMgr.previewSession())
                    .onAppear {
                        let savedID = UserDefaults.standard.integer(forKey: "CameraID")
                        if savedID != 0 {
                            selectedID = savedID
                        }
                        cameraMgr.switchLens(.wide)
                    }
                VStack {
                    HStack {
                        // 机位选择
                        Menu {
                            ForEach(1...4, id: \.self) { id in
                                Button("机位 \(id)") {
                                    selectedID = id
                                    setCameraID(id)
                                }
                            }
                        } label: {
                            Text("机位 \(selectedID)")
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        
                        // 镜头选择
                        Menu {
                            Button("广角 1x（48MP）") {
                                selectedLens = .wide
                                cameraMgr.switchLens(.wide)
                            }
                            Button("超广角 0.5x（12MP）") {
                                selectedLens = .ultraWide
                                cameraMgr.switchLens(.ultraWide)
                            }
                        } label: {
                            Text(selectedLens == .wide ? "1x" : "0.5x")
                                .padding(12)
                                .background(Color.blue.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        
                        // 重连
                        Button {
                            MacConnector.shared.reconnect()
                        } label: {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .padding(6)
                                .background(Color.gray.opacity(0.8))
                                .clipShape(Circle())
                        }
                        
                    }
                    .padding(.top)
                    
                    Spacer()
                    
                }
                    .edgesIgnoringSafeArea(.top)

            } else {
                Text("请授权相机访问")
                    .foregroundColor(.gray)
                    .onAppear { requestPermission() }
            }
        }
        .ignoresSafeArea()
    }

    private func requestPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    isAuthorized = granted
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setCameraID(_ id: Int) {
        UserDefaults.standard.set(id, forKey: "CameraID")
        UserDefaults.standard.synchronize()
        connector.sendCameraIDUpdate(id)
        print("📌 已保存机位号: \(id)")
    }
}






//
//  CameraPreviewView.swift
//  MultiCamiOS
//
//  Created by ZSS on 2025/8/6.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    class CameraPreviewLayer: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer? {
            return self.layer as? AVCaptureVideoPreviewLayer
        }

        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        func setSession(_ session: AVCaptureSession) {
            previewLayer?.session = session
            previewLayer?.videoGravity = .resizeAspectFill
            updateOrientation()
        }

        func updateOrientation() {
            guard let connection = previewLayer?.connection else { return }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation(deviceOrientation: UIDevice.current.orientation) ?? .portrait
            }
        }
    }

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewLayer {
        let view = CameraPreviewLayer()
        view.setSession(session)

        // 监听旋转
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            view.updateOrientation()
        }
        return view
    }

    func updateUIView(_ uiView: CameraPreviewLayer, context: Context) {
        uiView.updateOrientation()
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight   // 注意：设备左横屏 = 摄像头画面右转
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
}


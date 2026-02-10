//
//  CameraManager.swift
//  MultiCamiOS
//
//  Created by ZSS on 2025/8/7.
//

import AVFoundation
import Combine

final class CameraManager: NSObject, ObservableObject {

    static let shared = CameraManager()

    // MARK: - Core
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let photoOutput = AVCapturePhotoOutput()

    private var currentInput: AVCaptureDeviceInput?
    private var completionHandler: ((Data?) -> Void)?
    private var isCapturing = false

    // MARK: - State
    @Published private(set) var isConfigured = false

    enum LensMode {
        case wide       // 1x
        case ultraWide  // 0.5x
    }

    @Published private(set) var currentLens: LensMode = .wide

    // MARK: - Init
    override init() {
        super.init()
        configureSession()
    }

    // MARK: - Public
    func previewSession() -> AVCaptureSession {
        session
    }

    func switchLens(_ lens: LensMode) {
        sessionQueue.async {
            self.applyLens(lens)
        }
    }

    // MARK: - Session Setup
    private func configureSession() {
        sessionQueue.async {
            guard !self.isConfigured else { return }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            // 1️⃣ 先加 input（不设置 maxPhotoDimensions）
            self.applyLens(.wide, configureOutput: false)

            // 2️⃣ 再加 output
            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
                self.photoOutput.isHighResolutionCaptureEnabled = true
            }

            self.session.commitConfiguration()

            // 3️⃣ commit 后配置尺寸（安全）
            self.configurePhotoOutput(for: .wide)

            self.session.startRunning()

            DispatchQueue.main.async {
                self.isConfigured = true
            }

            print("✅ Camera Session 配置完成")
        }
    }

    // MARK: - Lens Apply
    private func applyLens(_ lens: LensMode, configureOutput: Bool = true) {
        let deviceType: AVCaptureDevice.DeviceType =
            (lens == .wide) ? .builtInWideAngleCamera : .builtInUltraWideCamera

        guard let device = AVCaptureDevice.default(deviceType,
                                                   for: .video,
                                                   position: .back) else {
            print("❌ 未找到摄像头: \(deviceType)")
            return
        }

        do {
            let newInput = try AVCaptureDeviceInput(device: device)

            session.beginConfiguration()

            if let currentInput {
                session.removeInput(currentInput)
            }

            if session.canAddInput(newInput) {
                session.addInput(newInput)
                currentInput = newInput
            }

            session.commitConfiguration()

            // ⚠️ 必须在 commit 之后
            if configureOutput {
                configurePhotoOutput(for: lens)
            }

            DispatchQueue.main.async {
                self.currentLens = lens
            }

            print("🔄 已切换镜头: \(lens)")
        } catch {
            session.commitConfiguration()
            print("❌ 切换镜头失败: \(error)")
        }
    }

    // MARK: - Photo Output Configuration
    private func configurePhotoOutput(for lens: LensMode) {

        guard photoOutput.connections.contains(where: { $0.isEnabled }) else {
            print("⚠️ PhotoOutput 尚未连接，跳过尺寸配置")
            return
        }

        guard let input = currentInput,
              input.device.activeFormat != nil else {
            print("⚠️ activeFormat 为 nil，跳过 maxPhotoDimensions")
            return
        }

        photoOutput.isHighResolutionCaptureEnabled = true

        if #available(iOS 17.0, *) {
            switch lens {
            case .wide:
                photoOutput.maxPhotoDimensions =
                    CMVideoDimensions(width: 8064, height: 6048)
                print("📐 使用 48MP 输出")

            case .ultraWide:
                photoOutput.maxPhotoDimensions =
                    CMVideoDimensions(width: 4032, height: 3024)
                print("📐 使用 12MP 输出")
            }
        }
    }
}

// MARK: - Photo Capture
extension CameraManager: AVCapturePhotoCaptureDelegate {

    func capture(completion: @escaping (Data?) -> Void) {
        guard !isCapturing else {
            print("⚠️ 正在拍照，忽略重复请求")
            return
        }

        isCapturing = true
        completionHandler = { [weak self] data in
            completion(data)
            self?.isCapturing = false
        }

        sessionQueue.async {
            guard self.isConfigured else {
                DispatchQueue.main.async {
                    self.isCapturing = false
                    completion(nil)
                }
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            settings.isHighResolutionPhotoEnabled = true

            if self.photoOutput.isStillImageStabilizationSupported {
                settings.isAutoStillImageStabilizationEnabled = false
            }

            print("📸 拍照触发（\(self.currentLens)）")
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Delegate
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {

        if let error {
            print("❌ 拍照失败: \(error)")
            DispatchQueue.main.async {
                self.completionHandler?(nil)
            }
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            DispatchQueue.main.async {
                self.completionHandler?(nil)
            }
            return
        }

        print("✅ 拍照完成，size = \(data.count)")
        DispatchQueue.main.async {
            self.completionHandler?(data)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
                     error: Error?) {

        if let error {
            print("❌ 拍照流程异常: \(error)")
        } else {
            print("📸 拍照流程结束")
        }
    }
}


//
//  SocketServer.swift
//  MultiCamMac
//
//  Created by ZSS on 2025/8/7.
//

import Foundation
import CocoaAsyncSocket
import AppKit

class SocketServer: NSObject, ObservableObject, GCDAsyncSocketDelegate {
    private var serverSocket: GCDAsyncSocket!
    private var service: NetService?
    
    // 磁盘写入队列
    private let diskQueue = DispatchQueue(
        label: "aoi.disk.write.queue",
        qos: .utility
    )

    
    private var clientBuffers: [GCDAsyncSocket: Data] = [:]
    private var expectedLengths: [GCDAsyncSocket: Int] = [:]
    private var cameraIDs: [GCDAsyncSocket: Int] = [:]   // socket 当前机位号
    private var appModel: AppModel
    
    init(appModel: AppModel) {
        self.appModel = appModel
        super.init()
        serverSocket = GCDAsyncSocket(
            delegate: self,
            delegateQueue: DispatchQueue(label: "aoi.socket.queue")
        )
        startServer()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(broadcastShutter),
            name: .triggerShutterCommand,
            object: nil
        )
    }
    
    func startServer() {
        do {
            try serverSocket.accept(onPort: 8080)
            print("✅ macOS 服务器启动成功，端口 8080")
            publishBonjourService()
        } catch { print("❌ 启动服务器失败: \(error.localizedDescription)") }
    }
    
    private func publishBonjourService() {
        service = NetService(domain: "local.", type: "_maccontrol._tcp.", name: "MacController", port: 8080)
        service?.publish()
        print("📡 Bonjour 服务发布成功: _maccontrol._tcp.")
    }
    
    // MARK: - Accept
    func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        print("📡 新客户端连接: \(newSocket.connectedHost ?? "?"):\(newSocket.connectedPort)")
        clientBuffers[newSocket] = Data()
        expectedLengths[newSocket] = nil
        cameraIDs[newSocket] = nil
        newSocket.readData(withTimeout: -1, tag: 0)
    }
    
    // MARK: - Read
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        guard var buffer = clientBuffers[sock] else { clientBuffers[sock] = Data(); return }
        buffer.append(data)
        
        // 循环解包：先读行协议，再读二进制块
        while true {
            if expectedLengths[sock] == nil {
                guard let lineBreak = buffer.firstIndex(of: 0x0A) else { break } // \n
                let headerData = buffer.subdata(in: 0..<lineBreak)
                buffer.removeSubrange(0...lineBreak)
                
                guard let headerStr = String(data: headerData, encoding: .utf8) else { continue }
                let parts = headerStr.split(separator: ";", omittingEmptySubsequences: false)
                
                // 安全分支匹配
                if parts.count == 2, parts[0] == "HELLO", let camID = Int(parts[1]) {
                    cameraIDs[sock] = camID
                    refreshCameraStatus()
                    print("🤝 HELLO: 机位 \(camID) 上线")
                    continue
                }
                
                // 更新机位号机制
                if parts.count == 2, parts[0] == "CAM_ID", let camID = Int(parts[1]) {
                    // 同一 socket 只能保留一条记录
                    cameraIDs[sock] = camID                  // 写入新机位号
                    refreshCameraStatus()
                    print("🔁 CAM_ID 更新为 \(camID)（旧条目已清理）")
                    continue
                }
                
                
                if parts.count >= 3, parts[0] == "IMAGE", let camID = Int(parts[1]), let len = Int(parts[2]) {
//                    guard self.appModel.currentStep != .step1 || camID != 4 else { continue }
                    cameraIDs[sock] = camID          // 以图片头为准更新一次
                    expectedLengths[sock] = len
                    refreshCameraStatus()
                    continue
                }
                
                print("❌ 无效头部: \(headerStr)")
            }
            
            // 进入读二进制块
            if let length = expectedLengths[sock] {
                guard buffer.count >= length else { break }
                let imageData = buffer.subdata(in: 0..<length)
                buffer.removeSubrange(0..<length)
                if let camID = cameraIDs[sock] { saveImageToDisk(imageData, cameraID: camID) }
                expectedLengths[sock] = nil
                continue
            }
        }
        
        clientBuffers[sock] = buffer
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    // MARK: - CameraUpdate
    
    private func refreshCameraStatus() {
        DispatchQueue.main.async {
            // 1. 全部置为 false
            for key in self.appModel.cameraStatus.keys {
                self.appModel.cameraStatus[key] = false
            }

            // 2. 根据当前在线 socket 映射置 true
            for cam in self.cameraIDs.values {
                self.appModel.cameraStatus[cam] = true
            }
        }
    }

    
    
    // MARK: - Disconnect
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        print("🔌 客户端断开连接: \(sock.connectedHost ?? "?"):\(sock.connectedPort)")
        
        // 2. 从所有映射里删除
        cameraIDs.removeValue(forKey: sock)
        clientBuffers.removeValue(forKey: sock)
        expectedLengths.removeValue(forKey: sock)
        
        // 1. 把机位置离线
        refreshCameraStatus()
        
    }
    
    
    // MARK: - Save
    
    private func saveImageToDisk(_ data: Data, cameraID: Int) {
        let sn = appModel.sn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sn.isEmpty else { return }

        let today = DateFormatter.yyyyMMdd.string(from: Date())

        let baseDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/AOI")
            .appendingPathComponent(today)
            .appendingPathComponent(sn)

        let fileName = "\(appModel.currentStep)_\(cameraID)_\(appModel.opID).jpg"
        let filePath = baseDir.appendingPathComponent(fileName)

        diskQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: baseDir,
                    withIntermediateDirectories: true
                )

                try data.write(to: filePath, options: .atomic)

                print("📸 已写盘: \(filePath.lastPathComponent)")

                // ⭐⭐⭐ 核心：Step3 写盘成功后立刻判定
                DispatchQueue.main.async {
                    if self.appModel.currentStep == .step3 {
                        self.checkStep3CompletionIfNeeded()
                    }
                }

            } catch {
                print("❌ 保存图片失败: \(error)")
            }
        }

        // UI 解码与显示（与磁盘完全解耦）
        if let nsImage = NSImage(data: data) {
            DispatchQueue.main.async {
                switch self.appModel.currentStep {
                case .step1:
                    self.appModel.previewsStep1[cameraID] = nsImage
                case .step2:
                    self.appModel.previewsStep2[cameraID] = nsImage
                case .step3:
                    self.appModel.previewsStep3[cameraID] = nsImage
                }
            }
        }
    }

    // MARK: - CheckStep3
    
    private func finishOneSN() {
        appModel.currentStep = .step1

        appModel.previewsStep1.removeAll()
        appModel.previewsStep2.removeAll()
        appModel.previewsStep3.removeAll()

        appModel.sn = ""
        appModel.code = ""
        appModel.focusField = .sn
    }

    
    private func showOfflineTip() {
        appModel.errorMessage = "机位离线请检查后重试"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.appModel.errorMessage = nil
        }
    }


    private func checkStep3CompletionIfNeeded() {
        guard appModel.currentStep == .step3 else { return }

        let sn = appModel.sn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sn.isEmpty else { return }

        let today = DateFormatter.yyyyMMdd.string(from: Date())

        let snDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/AOI")
            .appendingPathComponent(today)
            .appendingPathComponent(sn)

        diskQueue.async {
            let fileCount = (try? FileManager.default.contentsOfDirectory(
                at: snDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ).count) ?? 0

            let expected = self.appModel.step2switch ? 9 : 8

            print("🔎 Step3 判定: \(fileCount)/\(expected)")

            
                DispatchQueue.main.async {
                    if fileCount == expected {
                        self.appModel.reset()
                    } else {
                        self.appModel.showStep3IncompleteTip = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.appModel.currentStep = .step1
                            self.appModel.showStep3IncompleteTip = false
                    }
                }
            }
        }
    }

    
    // MARK: - 发指令
    
    // 通用过滤函数
    private func liveSockets(for targets: [Int]) -> [(socket: GCDAsyncSocket, cam: Int)] {
        cameraIDs.compactMap { (sock, cam) in
            sock.isConnected && targets.contains(cam) ? (sock, cam) : nil
        }
    }
    
    // 1. 单点发送
    func sendShutter(to targets: [Int]) {
        let msg = "shutter\n"
        guard let data = msg.data(using: .utf8) else { return }
        for (sock, cam) in liveSockets(for: targets) {
            sock.write(data, withTimeout: -1, tag: 0)
            print("📤 已向机位 \(cam) 发送 shutter 指令")
        }
    }
    
    // 2. 广播发送
    @objc private func broadcastShutter() {
        let msg = "shutter\n"
        guard let data = msg.data(using: .utf8) else { return }
        
        // Step2 模式且当前就是 Step2 → 只发 4 号
        if appModel.step2switch && appModel.currentStep == .step2 {
            for (sock, cam) in liveSockets(for: [4]) {
                sock.write(data, withTimeout: -1, tag: 0)
                print("📤 Step2 模式：向机位 4 发送 shutter")
            }
            return
        }
        
        // 其余情况：给所有在线机位发
        for (sock, cam) in liveSockets(for: Array(cameraIDs.values)) {
            sock.write(data, withTimeout: -1, tag: 0)
        }
        print("📤 已向所有在线机位发送 shutter")

    }
    
}

// 获取固定时间格式
private extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()
}

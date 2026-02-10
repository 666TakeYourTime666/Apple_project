//
//  MacConnector.swift
//  MultiCamiOS
//
//  Created by ZSS on 2025/8/7.
//

import Foundation
import CocoaAsyncSocket
import UIKit

class MacConnector: NSObject,
                     ObservableObject,
                     NetServiceBrowserDelegate,
                     NetServiceDelegate,
                     GCDAsyncSocketDelegate {
    
    static let shared = MacConnector()
    
    private var browser = NetServiceBrowser()
    private var service: NetService?
    private var socket: GCDAsyncSocket!       // 立即强引用
    
    let deviceUUID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    
    var src: [[String: String]] = []
    var dest: [[String: String]] = []
    
    // 使用 shared 单例后 init 也必须 private
    private override init() {
        super.init()
        socket = GCDAsyncSocket(delegate: self, delegateQueue: .main)
        browser.delegate = self
        browser.searchForServices(ofType: "_maccontrol._tcp.", inDomain: "local.")
        print("📡 正在搜索 macOS 服务...")
    }
    
    // MARK: - Bonjour
    func netServiceBrowser(_ browser: NetServiceBrowser,
                           didFind service: NetService,
                           moreComing: Bool) {
        self.service = service
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        print("🔍 发现服务: \(service.name)")
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        for address in sender.addresses ?? [] {
            do {
                try socket.connect(toAddress: address)
                print("✅ 已连接 macOS: \(sender.name)")
                return
            } catch {
                print("❌ 连接失败: \(error)")
            }
        }
        print("❌ 无法连接: 无效地址")
    }
    
    
    // MARK: - reconnect
    
    func reconnect() {
        print("🔄 手动重连中...")

        socket.disconnect()
        service = nil

        browser.stop()
        browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: "_maccontrol._tcp.", inDomain: "local.")
    }

    
    
    // MARK: - Socket
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        print("🎉 成功连接到 macOS: \(host):\(port)")
        
        let cameraID = UserDefaults.standard.integer(forKey: "CameraID")
        let handshakeMessage = "HELLO;\(cameraID)\n"
        if let data = handshakeMessage.data(using: .utf8) {
            sock.write(data, withTimeout: -1, tag: 0)
        }
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
        guard let message = String(data: data, encoding: .utf8) else {
            sock.readData(withTimeout: -1, tag: 0)
            return
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        print("📥 收到 macOS 指令: \(trimmed)")
        
        if trimmed == "shutter" {
            handleShutterCommand(sock: sock)
        }
        
        sock.readData(withTimeout: -1, tag: 0)
    }
    
    // MARK: - 拍照
    func handleShutterCommand(sock: GCDAsyncSocket) {
        print("📸 收到 shutter 命令，准备拍照")
        CameraManager.shared.capture { imageData in
            guard let data = imageData else { print("❌ 拍照失败"); return }
            let cameraID = UserDefaults.standard.integer(forKey: "CameraID")
            self.sendImage(to: sock, imageData: data, cameraID: cameraID)
        }
    }
    
    func sendImage(to socket: GCDAsyncSocket, imageData: Data, cameraID: Int) {
        let header = "IMAGE;\(cameraID);\(imageData.count)\n"
        guard let headerData = header.data(using: .utf8) else { return }
        socket.write(headerData, withTimeout: -1, tag: 0)
        socket.write(imageData, withTimeout: -1, tag: 0)
        print("📤 已发送图片，机位 \(cameraID)，大小: \(imageData.count) bytes")
    }
    
    // MARK: - CameraID 更新
    func sendCameraIDUpdate(_ id: Int) {
        guard let sock = socket else { return }
        let msg = "CAM_ID;\(id)\n"
        sock.write(msg.data(using: .utf8)!, withTimeout: -1, tag: 0)
        print("📨 已发送机位更新 CAM_ID:\(id)")
    }
    
    // MARK: - 机位表处理
    func handleFile(data: Data) {
        // 同你原项目逻辑
    }
    
    func handleReceivedSrc(_ newSrc: [[String: String]]) {
        self.src = newSrc
        print("📋 更新本地机位表 src: \(newSrc)")
    }
    
    func selectCameraPosition(_ position: String) {
        // 保留原项目逻辑
    }
    
    func sendDestToMac(_ position: String) {
        // 保留原项目逻辑
    }
    
    func showAlert(_ message: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "确定", style: .default))
            UIApplication.shared.windows.first?.rootViewController?.present(alert, animated: true)
        }
    }
}







//
//  AppModel.swift
//  MultiCamMac
//
//  Created by ZSS on 2025/8/7.
//

import Foundation
import SwiftUI

class AppModel: ObservableObject {
    
    // 接入SocketServer
    var socketServer: SocketServer?
    
    // step3错误提示
    @Published var showStep3IncompleteTip = false
    
    // 用户输入字段
    @Published var opID: String = ""
    @Published var sn: String = ""
    @Published var code: String = ""
    
    
    
    // 当前流程状态
    @Published var currentStep: StepState = .step1

    // 当前输入焦点
    @Published var focusField: FocusField? = .opID

    // 机位在线状态（1~4）
    @Published var cameraStatus: [Int: Bool] = [
        1: false,
        2: false,
        3: false,
        4: false
    ]

    // 当前接收到的预览图（按机位号）
    @Published var previewsStep1: [Int: NSImage] = [:]
    @Published var previewsStep2: [Int: NSImage] = [:]
    @Published var previewsStep3: [Int: NSImage] = [:]
        

    // 工具状态标志
//    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    
    // Step2开关
    @Published var step2switch: Bool = false

    // 可选输入字段焦点枚举
    enum FocusField {
        case opID
        case sn
        case code
    }

    // 流程状态
    enum StepState: String {
        case step1 = "Step1"
        case step2 = "Step2"
        case step3 = "Step3"

    }
    
    // 切换流程状态（UI按钮也会调用）
    @Published var showStep2DisabledTip = false
    func switchToStep(_ step: StepState) {
        // 关键：Step2 被禁用时不允许进入
            if step == .step2 && !step2switch {
                NSSound.beep()
                // 触发提示
                showStep2DisabledTip = true
                // 3 秒后自动消失
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.showStep2DisabledTip = false
                    }
                print("⚠️ Step2 已关闭，拒绝切换")
                return
            }
        currentStep = step
        focusField = .code

    }

    // 清空状态（用于完成后 reset）
    func reset() {
        sn = ""
        code = ""
        currentStep = .step1
        DispatchQueue.main.async {
                self.focusField = .sn
            }
        previewsStep1 = [:]
        previewsStep2 = [:]
        previewsStep3 = [:]
    }
    
    var currentStepLabel: String {
        switch currentStep {
        case .step1: return "Step1"
        case .step2: return "Step2"
        case .step3: return "Step2"
        }
    }

}

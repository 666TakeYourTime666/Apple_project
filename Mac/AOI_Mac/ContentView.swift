//
//  ContentView.swift
//  AOI_Mac
//
//  Created by ZSS on 2025/8/18.
//

import SwiftUI
import Foundation


extension Color {
    static let lightBlue = Color(red: 0.6, green: 0.85, blue: 1.0)
    static let lightGrayBox = Color(red: 0.75, green: 0.75, blue: 0.75)
}

struct ContentView: View {
    // 注入AppModel
    @EnvironmentObject var appModel: AppModel
    
    @State private var opID: String = ""
    @State private var sn: String = ""
    @State private var code: String = ""
    

    var body: some View {
        
        ZStack {
            VStack(spacing: 0) {
                Text("多机位模式")
                    .font(.system(size: 30,weight: .thin))
                    .foregroundStyle(.black)
                    .padding(.vertical,10)
                    .padding(.horizontal,40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.9))
                    )
                    .padding(.top,20)
                
                HStack(spacing: 0) {
                    // 左侧流程 + 机位状态
                    VStack(spacing: 10) {
                        
                        TopBarView(step: $appModel.currentStep)
                        
                        ForEach(1..<5) { index in
                            CameraStatusView(cameraNumber: index, isOnline: appModel.cameraStatus[index] ?? false)
                        }
                        
                        Spacer()
                    }
                    .frame(width: 150)
                    .padding()
                    
                    Divider()
                    
                    // 右侧图片预览
                    let previews: [Int : NSImage] = {
                        switch appModel.currentStep {
                        case .step1: return appModel.previewsStep1
                        case .step2: return appModel.previewsStep2
                        case .step3: return appModel.previewsStep3
                        }
                    }()
                    let shouldShowAll = appModel.currentStep == .step2
                    
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            PreviewBoxView(title: "机位 1", image: shouldShowAll ?  nil : previews[1])
                            
                            PreviewBoxView(title: "机位 2", image: shouldShowAll ?  nil : previews[2])
                        }
                        HStack(spacing: 16) {
                            PreviewBoxView(title: "机位 3", image: shouldShowAll ?  nil : previews[3])
                            PreviewBoxView(title: "机位 4", image: previews[4])
                        }
                    }
                    .padding()
                    
                }
                
                Divider()
                
                // 底部输入栏
                BottomInputBarView()
                
            }
            .background(Color.white)
            .frame(minWidth: 900, minHeight: 600)
            
            // 提示浮层
            if appModel.showStep2DisabledTip || appModel.showStep3IncompleteTip {
                    VStack {
                        
                        
                        Text(appModel.showStep2DisabledTip
                             ? "Step2 已关闭，请开启后重试！"
                             : "机位离线或图片未完整，请检查后重试")
                            .font(.title3.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 24)
                        
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.85))
                                    .shadow(radius: 8)
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            .animation(.easeInOut(duration: 0.25), value: appModel.showStep2DisabledTip)
                        
                        
                    }
                    .
                
                padding(.top, 80) // 贴顶部留点空隙
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.25))
                    .edgesIgnoringSafeArea(.all)
                    
                }
            
            if let msg = appModel.errorMessage {
                Text(msg)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
            }

        }
    }
}

struct TopBarView: View {
    @Binding var step: AppModel.StepState
    @EnvironmentObject var appModel: AppModel   // 拿开关

    var body: some View {
        HStack {
            StepButton(title: "Step1", active: step == .step1) { step = .step1 }
            StepButton(title: "Step2", active: step == .step2) { step = .step2 }
            
        }

        StepButton(title: "Step3", active: step == .step3) { step = .step3 }
        
        Button(action: { appModel.step2switch.toggle()
            step = .step1
        }) {
            HStack {
                Text("Step2 \(appModel.step2switch ? "开启" : "关闭")")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
                
                Image(systemName: appModel.step2switch ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(appModel.step2switch ? .green : .secondary)
                    .font(.system(size: 22)) // 可选：统一图标大小
            }
            .padding(.horizontal,14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lightGrayBox) // 使用系统背景色，适配深色模式
            )
        }
        .buttonStyle(PlainButtonStyle())
        .help(appModel.step2switch ? "关闭 Step2 拍摄" : "开启 Step2 拍摄")
        
    }
}

/// 把重复样式抽一个小组件
private struct StepButton: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Text(title)
            .foregroundColor(active ? .blue : .black)
            .frame(maxWidth: .infinity)
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.lightGrayBox)
            )
            .onTapGesture(perform: action)
    }
}

struct CameraStatusView: View {
    var cameraNumber: Int
    var isOnline: Bool
    
    
    var body: some View {
        let statusText = isOnline ? "在线" : "离线"
        let bgColor = Color.lightGrayBox
        
        return Text("机位\(cameraNumber):\(statusText)")
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgColor)
            )
            .foregroundStyle(.black)
    }
}

struct PreviewBoxView: View {
    let title: String
    let image: NSImage?

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let image = image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else {
                    Color.gray
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                        .overlay(
                            Text("暂无图片")
                                .foregroundColor(.white)
                        )
                }
            }

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
    }
}


extension Notification.Name {
    static let triggerShutterCommand = Notification.Name("triggerShutterCommand")
}

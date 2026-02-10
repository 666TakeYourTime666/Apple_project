//
//  BottomInputBarView.swift
//  MultiCamMac
//
//  Created by ZSS on 2025/8/6.
//

import SwiftUI

struct BottomInputBarView: View {
    @EnvironmentObject var appModel: AppModel
    @FocusState private var focusedField: AppModel.FocusField?

    var body: some View {
        HStack(spacing: 20) {
            Group {
                TextField("扫描工号", text: $appModel.opID)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .opID)
                    .onSubmit { appModel.focusField = .sn }

                TextField("扫描SN", text: $appModel.sn)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .sn)
                    .onSubmit { appModel.focusField = .code }

                TextField("扫描CODE", text: $appModel.code)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .code)
                    .onSubmit { handleCodeInput() }
            }
        }
        .padding()
        .onAppear { appModel.focusField = .opID }
        // 让本地 focusedField 和 appModel.focusField 保持同步
        .onChange(of: focusedField) { newValue in
            appModel.focusField = newValue
        }
        .onChange(of: appModel.focusField) { newValue in
            focusedField = newValue
        }
    }

    private func handleCodeInput() {
        let command = appModel.code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch command {
        case "shutter":
            if appModel.currentStep == .step3 {

                appModel.socketServer?.sendShutter(to: [1,2,3,4])

            } else {
                NotificationCenter.default.post(name: .triggerShutterCommand, object: nil)
            }

        case "step1":
            appModel.switchToStep(.step1)

        case "step2":
            appModel.switchToStep(.step2)
            
        case "step3":
            appModel.switchToStep(.step3)

        default:
            appModel.errorMessage = "❌ 无效指令: \(command)"
        }

        appModel.code = ""
    }
}





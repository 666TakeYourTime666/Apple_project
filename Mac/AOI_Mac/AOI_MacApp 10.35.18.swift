//
//  AOI_MacApp.swift
//  AOI_Mac
//
//  Created by ZSS on 2025/8/18.
//

import SwiftUI

@main
struct AOI_MacApp: App {
    @StateObject private var appModel: AppModel
    @StateObject private var socketServer: SocketServer

    init() {
        let model = AppModel()
        let server = SocketServer(appModel: model)
        model.socketServer = server
        _appModel = StateObject(wrappedValue: model)
        _socketServer = StateObject(wrappedValue: server)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .environmentObject(socketServer)
        }
    }
}

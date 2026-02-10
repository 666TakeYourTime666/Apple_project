//
//  AOI_iOSApp.swift
//  AOI_iOS
//
//  Created by ZSS on 2025/8/18.
//

import SwiftUI

@main
struct AOI_iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        WindowGroup {
            CameraView()
            
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    var connector: MacConnector?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        connector = MacConnector.shared
        return true
    }
}


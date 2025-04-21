//
//  ThunkVideoProcessorApp.swift
//  ThunkVideoProcessor
//
//  Created by Ty Alevizos on 4/18/25.
//

import SwiftUI
import Firebase
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication,
                    open url: URL,
                    options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}

@main
struct ThunkVideoProcessorApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    init() {
           // Register URL scheme for Google Sign-In
           if let urlScheme = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]],
              let firstScheme = urlScheme.first,
              let schemes = firstScheme["CFBundleURLSchemes"] as? [String],
              let scheme = schemes.first {
               GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: "YOUR_CLIENT_ID", serverClientID: scheme)
           }
       }
    
    var body: some Scene {
        WindowGroup {
            SplashScreenView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    }
}

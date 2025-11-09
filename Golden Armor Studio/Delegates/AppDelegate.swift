//
//  AppDelegate.swift
//  Golden Armor Studio
//
//  Created by RobloxHero on 11/2/25.
//

import UIKit
import FirebaseCore

@UIApplicationMain
@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureFirebaseIfNeeded()
        _ = AuthSession.shared
        window?.backgroundColor = .black
        return true
    }

    private func configureFirebaseIfNeeded() {
        guard FirebaseApp.app() == nil else { return }

        if let filePath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
           let options = FirebaseOptions(contentsOfFile: filePath) {
            print("[AppDelegate] Configuring Firebase using bundled GoogleService-Info.plist at: \(filePath)")
            FirebaseApp.configure(options: options)
            return
        }

        let options = FirebaseOptions(googleAppID: "1:732128551566:ios:c75928cf35c7a7ef4a9fdf", gcmSenderID: "732128551566")
        options.apiKey = "AIzaSyCfI_l0bf1PAxzCkovZCkRnnKKJpeZA5Q4"
        options.projectID = "goldenarmorstudios"
        options.storageBucket = "goldenarmorstudios.firebasestorage.app"
        print("[AppDelegate] Configuring Firebase using fallback FirebaseOptions.")
        FirebaseApp.configure(options: options)
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    @available(iOS, deprecated: 26.0, message: "Handle incoming URLs via UIScene APIs when available.")
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        if AuthSession.shared.handleOpenURL(url) {
            return true
        }
        return false
    }

}

//
//  InterviewIQApp.swift
//  InterviewIQ
//
//  Created by Clarice Harijanto on 04/05/26.
//https://github.com/firebase/firebase-ios-sdk

import SwiftUI
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - UIApplicationDelegate
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Essential configuration call to establish connection to the Firebase BaaS ecosystem
        FirebaseApp.configure()
        return true
    }
}

@main
struct InterviewIQApp: App {
    // MARK: - Properties
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                // One brand accent across every screen, modal, and system control.
                .tint(Studio.Palette.accent)
                // Locked to light — InterviewIQ has a single, branded light identity.
                .preferredColorScheme(.light)
        }
    }
}
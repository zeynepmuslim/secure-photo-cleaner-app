//
//  UITestingLaunchMode.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.11.2026.
//

import Foundation

/// The `-uiTesting` launch argument (Debug builds only): `PurgioUITests` launch the app with it so every run starts
/// from a clean slate. In Release it does nothing.
/// - `-uiTesting`: wipes `Documents/Purgio/` and `Documents/undoHistory.json`, resets the app's defaults domain,
///   marks onboarding done and skips the launch splash.
/// - `-uiTestingOnboarding` (with `-uiTesting`): leaves onboarding not done, so it shows.
enum UITestingLaunchMode {

    static let argument = "-uiTesting"
    static let onboardingArgument = "-uiTestingOnboarding"

    static var isActive: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(argument)
        #else
        return false
        #endif
    }

    static var skipsSplash: Bool { isActive }

    /// Call first in `didFinishLaunching`, before any store's `.shared` loads its file.
    static func prepareIfNeeded() {
        #if DEBUG
        guard isActive else { return }

        let fileManager = FileManager.default
        if let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? fileManager.removeItem(at: documents.appendingPathComponent("Purgio", isDirectory: true))
            try? fileManager.removeItem(at: documents.appendingPathComponent("undoHistory.json"))
        }

        if let domain = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: domain)
        }

        let showsOnboarding = ProcessInfo.processInfo.arguments.contains(onboardingArgument)
        if !showsOnboarding {
            OnboardingStore.shared.hasCompletedOnboarding = true
        }

        print("[UITestingLaunchMode] Reset app data (onboarding \(showsOnboarding ? "shows" : "done"))")
        #endif
    }
}

//
//  AppDelegate.swift
//  Purgio
//
//  Created by ZeynepMüslim on 3.01.2026.
//

import BackgroundTasks
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        ThemeManager.configureNavigationBarAppearance()

        SettingsStore.shared.endTemporaryInternetOverride()

        registerBackgroundTasks()
        preloadMonthBucketsCacheIfAuthorized()

        UNUserNotificationCenter.current().delegate = ReminderNotificationService.shared
        ReminderNotificationService.shared.registerCategories()

        _ = TipJarManager.shared // for init Transaction.updates

        return true
    }

    // MARK: - Cache Preloading

    private func preloadMonthBucketsCacheIfAuthorized() {
        let status = PhotoLibraryService.shared.authorizationStatus()
        guard status == .authorized || status == .limited else {
            return
        }
        PhotoLibraryService.shared.preloadMonthBucketsCache()
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: StorageAnalysisManager.backgroundTaskIdentifier,
            using: nil
        ) { task in
            self.handleStorageAnalysisBackgroundTask(task: task as! BGProcessingTask)
        }

        print("[AppDelegate] Background tasks registered")
    }

    private func handleStorageAnalysisBackgroundTask(task: BGProcessingTask) {
        StorageAnalysisManager.shared.handleBackgroundTask(task: task)
    }

    // MARK: - UISceneSession Lifecycle

    func application(
        _ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

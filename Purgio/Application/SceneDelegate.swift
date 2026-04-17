//
//  SceneDelegate.swift
//  Purgio
//
//  Created by ZeynepMüslim on 3.01.2026.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        // Home/Dashboard tab
        let dashboardViewController = HomeViewController()
        let dashboardNavController = UINavigationController(rootViewController: dashboardViewController)
        dashboardNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.home", comment: "Home tab title"),
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )

        // Photos tab
        let photosViewController = MonthsListViewController(mediaType: .image)
        let photosNavController = UINavigationController(rootViewController: photosViewController)
        photosNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.photos", comment: "Photos tab title"),
            image: UIImage(systemName: "photo"),
            selectedImage: UIImage(systemName: "photo.fill")
        )

        // Videos tab
        let videosViewController = MonthsListViewController(mediaType: .video)
        let videosNavController = UINavigationController(rootViewController: videosViewController)
        videosNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.videos", comment: "Videos tab title"),
            image: UIImage(systemName: "video"),
            selectedImage: UIImage(systemName: "video.fill")
        )

        // Settings tab
        let settingsViewController = SettingsViewController()
        let settingsNavController = UINavigationController(rootViewController: settingsViewController)
        settingsNavController.tabBarItem = UITabBarItem(
            title: NSLocalizedString("tab.settings", comment: "Settings tab title"),
            image: UIImage(systemName: "gearshape"),
            selectedImage: UIImage(systemName: "gearshape.fill")
        )

        // Tab bar controller
        let tabBarController = MainTabBarController()
        tabBarController.viewControllers = [
            dashboardNavController, photosNavController, videosNavController, settingsNavController
        ]

        window.rootViewController = tabBarController
        window.makeKeyAndVisible()
        self.window = window

        ReminderNotificationService.shared.syncScheduleIfNeeded()
//        #if DEBUG
//            ReminderNotificationService.shared.debugPrintSampleReminders()
//        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeepLinkToDeleteBin),
            name: .notificationDeepLinkToDeleteBin,
            object: nil
        )
    }

    @objc private func handleDeepLinkToDeleteBin() {
        guard let tabBarController = window?.rootViewController as? MainTabBarController else { return }

        // Switch to Photos tab (index 1)
        tabBarController.selectedIndex = 1

        guard let navController = tabBarController.viewControllers?[1] as? UINavigationController else { return }
        navController.popToRootViewController(animated: false)
        navController.pushViewController(DeleteBinViewController(), animated: true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }

}

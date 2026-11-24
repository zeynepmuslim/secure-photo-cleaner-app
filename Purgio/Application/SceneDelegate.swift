//
//  SceneDelegate.swift
//  Purgio
//
//  Created by ZeynepMüslim on 3.01.2026.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var splashWindow: UIWindow?
    private var hasPendingSplash = false
    /// How long the system's cross-fade into the app takes (measured on the simulator: about 0.3 s).
    private static let launchFadeInWait: TimeInterval = 0.35

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

        showLaunchSplash(in: windowScene)

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

    /// Cold launch only: plays the splash in its own window above Home, so Home's onboarding or
    /// permission sheet (presented from its `viewDidAppear`) stays underneath and is revealed with it.
    private func showLaunchSplash(in windowScene: UIWindowScene) {
        let splashViewController = LaunchSplashViewController()
        let splashWindow = UIWindow(windowScene: windowScene)
        splashWindow.windowLevel = .normal + 1
        splashWindow.rootViewController = splashViewController
        splashWindow.isHidden = false
        self.splashWindow = splashWindow
        splashWindow.layoutIfNeeded()
        // Plays from `sceneDidBecomeActive`: before that the window may not be on screen yet,
        // and the slide would run unseen.
        hasPendingSplash = true
    }

    private func playPendingLaunchSplash() {
        guard hasPendingSplash,
              let splashView = (splashWindow?.rootViewController as? LaunchSplashViewController)?.splashView
        else { return }
        hasPendingSplash = false
        // When the system has no launch-screen snapshot (the iPhone Duo, a fresh install) it cross-fades
        // into the app from black as the scene becomes active; wait that out so the slide starts on a
        // fully visible icon. Where the storyboard did show, this is just a longer still frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.launchFadeInWait) { [weak self] in
            splashView.play {
                self?.splashWindow?.isHidden = true
                self?.splashWindow = nil
            }
        }
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
        playPendingLaunchSplash()
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

// MARK: - LaunchSplashViewController

/// The splash window's root: its view is the `LaunchSplashView`.
private final class LaunchSplashViewController: UIViewController {
    let splashView = LaunchSplashView()

    override func loadView() {
        view = splashView
    }
}

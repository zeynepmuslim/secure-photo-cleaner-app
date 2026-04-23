//
//  StorageAnalysisManager+AppLifecycle.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import BackgroundTasks
import UIKit

extension StorageAnalysisManager {
    func setupAppLifecycleObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhotoAuthorizationGranted),
            name: .photoAuthorizationGranted,
            object: nil
        )
    }

    @objc func handlePhotoAuthorizationGranted() {
        print("[StorageAnalysis] Photo authorization granted - running analysis")
        refreshIfNeeded()
    }

    @objc func appWillTerminate() {
        print("[StorageAnalysis] App will terminate - ending Live Activity")
        endLiveActivityImmediatelyIfAvailable()
    }

    @objc func appWillResignActive() {
        guard isAnalysisRunning else { return }
        print("[StorageAnalysis] App will resign active - preparing for background")

        isInBackground = true
    }

    @objc func appDidEnterBackground() {
        isInBackground = true
        guard hasResumableProgress || isAnalysisRunning else { return }

        print("[StorageAnalysis] App entered background - starting immediate background execution")

        startUIBackgroundTask()
        scheduleBackgroundTask()
    }

    @objc func appDidBecomeActive() {
        isInBackground = false

        endUIBackgroundTask()
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)

        guard hasResumableProgress else { return }

        print("[StorageAnalysis] App became active - resuming in foreground")

        if !isAnalysisRunning {
            isCancelled = false
            resumeAnalysis()
        } else {
            // Analysis is wrapping up on background thread (responding to cancellation).
            // Check again shortly — handlePause will set isAnalysisRunning = false.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                if !self.isAnalysisRunning && self.hasResumableProgress {
                    print("[StorageAnalysis] Deferred resume after background pause")
                    self.isCancelled = false
                    self.resumeAnalysis()
                }
            }
        }
    }
}

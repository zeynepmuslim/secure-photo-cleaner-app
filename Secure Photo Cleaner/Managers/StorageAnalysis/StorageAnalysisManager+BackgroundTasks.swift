//
//  StorageAnalysisManager+BackgroundTasks.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import BackgroundTasks
import UIKit

extension StorageAnalysisManager {
    static let backgroundTaskIdentifier = "com.securephotocleaner.storageAnalysis"
}

extension StorageAnalysisManager {

    func startUIBackgroundTask() {
        guard uiBackgroundTaskId == .invalid else { return }

        uiBackgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "StorageAnalysis") { [weak self] in
            print("[StorageAnalysis] UIKit background task expiring - pausing analysis")
            self?.isCancelled = true
            self?.endUIBackgroundTask()
        }

        print("[StorageAnalysis] UIKit background task started (id: \(uiBackgroundTaskId.rawValue))")

        let remainingTime = UIApplication.shared.backgroundTimeRemaining
        if remainingTime < Double.greatestFiniteMagnitude {
            print("[StorageAnalysis] Background time remaining: \(String(format: "%.1f", remainingTime)) seconds")
        }
    }

    func endUIBackgroundTask() {
        guard uiBackgroundTaskId != .invalid else { return }

        print("[StorageAnalysis] Ending UIKit background task")
        UIApplication.shared.endBackgroundTask(uiBackgroundTaskId)
        uiBackgroundTaskId = .invalid
    }
}

extension StorageAnalysisManager {

    func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: Self.backgroundTaskIdentifier)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        request.earliestBeginDate = Date(timeIntervalSinceNow: 1)

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[StorageAnalysis] Background task scheduled successfully")
        } catch {
            print("[StorageAnalysis] Failed to schedule background task: \(error)")
        }
    }

    // Call by AppDelegate
    func handleBackgroundTask(task: BGProcessingTask) {
        print("[StorageAnalysis] Background task started")

        scheduleBackgroundTask()

        task.expirationHandler = { [weak self] in
            print("[StorageAnalysis] Background task expired")
            self?.isCancelled = true
        }

        isCancelled = false
        setIsAnalysisRunning(true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performChunkedAnalysis()

            let success = self?.currentProgress?.isComplete ?? true
            self?.setIsAnalysisRunning(false)

            task.setTaskCompleted(success: success)
            print("[StorageAnalysis] Background task completed (success: \(success))")
        }
    }
}

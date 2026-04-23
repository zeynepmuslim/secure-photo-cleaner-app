//
//  StorageAnalysisManager+LiveActivity.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import ActivityKit
import UIKit

extension StorageAnalysisManager {

    func cleanupStaleActivities() {
        if #available(iOS 16.2, *) {

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }

                guard !self.isAnalysisRunning else {
                    print("[StorageAnalysis] Skipping stale activity cleanup - analysis is running")
                    return
                }

                Task { @MainActor in
                    for activity in Activity<StorageAnalysisAttributes>.activities {
                        print("[StorageAnalysis] Found existing Live Activity: \(activity.id)")
                        await activity.end(
                            ActivityContent(state: activity.content.state, staleDate: nil),
                            dismissalPolicy: .immediate
                        )
                        print("[StorageAnalysis] Cleaned up stale Live Activity: \(activity.id)")
                    }
                }
            }
        }
    }

    @available(iOS 16.2, *)
    func startLiveActivity() {
        Task { @MainActor in
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                print("[StorageAnalysis] Live Activities are not enabled")
                return
            }

            endLiveActivity()   //end any existing activity

            let sessionId = UUID().uuidString
            currentSessionId = sessionId

            let attributes = StorageAnalysisAttributes(
                startTime: Date(),
                sessionId: sessionId
            )

            let initialState = StorageAnalysisAttributes.ContentState(
                analyzedCount: currentProgress?.photosProcessedCount ?? 0,
                totalCount: currentProgress?.photosTotalCount ?? 0,
                phase: .photos,
                statusMessage: "Starting analysis...",
                progress: currentProgress?.overallProgress ?? 0,
                bytesAnalyzed: (currentProgress?.photosBytes ?? 0) + (currentProgress?.videosBytes ?? 0)
            )

            do {
                let staleDate = Date(timeIntervalSinceNow: 30)
                currentActivity = try Activity.request(
                    attributes: attributes,
                    content: .init(state: initialState, staleDate: staleDate),
                    pushType: nil
                )
                print("[StorageAnalysis] Live Activity started")
            } catch {
                print("[StorageAnalysis] Failed to start Live Activity: \(error)")
            }
        }
    }

    @available(iOS 16.2, *)
    func updateLiveActivity(progress: StorageAnalysisProgress, phase: StorageAnalysisAttributes.AnalysisPhase) {
        guard let activity = currentActivity else { return }

        let totalCount = progress.photosTotalCount + progress.videosTotalCount
        let analyzedCount = progress.photosProcessedCount + progress.videosProcessedCount
        let bytesAnalyzed = progress.photosBytes + progress.videosBytes

        let statusMessage: String
        switch phase {
        case .photos:
            statusMessage = "Analyzing photos... (\(progress.photosProcessedCount)/\(progress.photosTotalCount))"
        case .videos:
            statusMessage = "Analyzing videos... (\(progress.videosProcessedCount)/\(progress.videosTotalCount))"
        case .complete:
            statusMessage = "Analysis complete"
        }

        let updatedState = StorageAnalysisAttributes.ContentState(
            analyzedCount: analyzedCount,
            totalCount: totalCount,
            phase: phase,
            statusMessage: statusMessage,
            progress: progress.overallProgress,
            bytesAnalyzed: bytesAnalyzed
        )

        Task { @MainActor in
            let staleDate = Date(timeIntervalSinceNow: 30)
            await activity.update(
                ActivityContent(state: updatedState, staleDate: staleDate)
            )
        }
    }

    @available(iOS 16.2, *)
    func endLiveActivity(showComplete: Bool = false) {
        guard let activity = currentActivity else { return }

        currentActivity = nil

        let photosProcessed = currentProgress?.photosProcessedCount ?? 0
        let videosProcessed = currentProgress?.videosProcessedCount ?? 0
        let photosTotal = currentProgress?.photosTotalCount ?? 0
        let videosTotal = currentProgress?.videosTotalCount ?? 0

        let finalState = StorageAnalysisAttributes.ContentState(
            analyzedCount: photosProcessed + videosProcessed,
            totalCount: photosTotal + videosTotal,
            phase: .complete,
            statusMessage: showComplete ? "Analysis completed" : "Analysis paused",
            progress: showComplete ? 1.0 : (currentProgress?.overallProgress ?? 0),
            bytesAnalyzed: (currentProgress?.photosBytes ?? 0) + (currentProgress?.videosBytes ?? 0)
        )

        Task { @MainActor in
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: showComplete ? .after(.now + 10) : .immediate
            )
            print("[StorageAnalysis] Live Activity ended")
        }
    }

    func startLiveActivityIfAvailable() {
        if #available(iOS 16.2, *) {
            startLiveActivity()
        }
    }

    func updateLiveActivityIfAvailable(
        progress: StorageAnalysisProgress, phase: StorageAnalysisAttributes.AnalysisPhase
    ) {
        if #available(iOS 16.2, *) {
            updateLiveActivity(progress: progress, phase: phase)
        }
    }

    func endLiveActivityIfAvailable(showComplete: Bool = false) {
        if #available(iOS 16.2, *) {
            endLiveActivity(showComplete: showComplete)
        }
    }

    @available(iOS 16.2, *)
    func endLiveActivityImmediately() {
        guard let activity = currentActivity else { return }
        currentActivity = nil

        let finalState = StorageAnalysisAttributes.ContentState(
            analyzedCount: (currentProgress?.photosProcessedCount ?? 0) + (currentProgress?.videosProcessedCount ?? 0),
            totalCount: (currentProgress?.photosTotalCount ?? 0) + (currentProgress?.videosTotalCount ?? 0),
            phase: .complete,
            statusMessage: "Analysis paused",
            progress: currentProgress?.overallProgress ?? 0,
            bytesAnalyzed: (currentProgress?.photosBytes ?? 0) + (currentProgress?.videosBytes ?? 0)
        )

        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
            semaphore.signal()
        }
        _ = semaphore.wait(timeout: .now() + 2.0)
        print("[StorageAnalysis] Live Activity ended (immediate)")
    }

    func endLiveActivityImmediatelyIfAvailable() {
        if #available(iOS 16.2, *) {
            endLiveActivityImmediately()
        }
    }
}

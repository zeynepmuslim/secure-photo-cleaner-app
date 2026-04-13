//
//  StorageAnalysisManager+ChunkedAnalysis.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import Photos
import UIKit

extension StorageAnalysisManager {

    func performChunkedAnalysis() {
        let sessionId = activeSessionId
        isCancelled = false

        let startTime = Date()
        print("[StorageAnalysis] Starting chunked analysis at \(startTime) [session \(sessionId)]")

        var progress = currentProgress ?? StorageAnalysisProgress.fresh()

        print("[StorageAnalysis] Fetching device storage info...")
        do {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey
            ])
            progress.totalDeviceBytes = Int64(values.volumeTotalCapacity ?? 0)
            progress.availableBytes = values.volumeAvailableCapacityForImportantUsage ?? 0
            print(
                "[StorageAnalysis] Device storage: \(progress.totalDeviceBytes.formattedBytes()) total, \(progress.availableBytes.formattedBytes()) available"
            )

            DispatchQueue.main.async { [weak self] in
                self?.setCurrentState(
                    .loadingWithBasicInfo(
                        totalBytes: progress.totalDeviceBytes, availableBytes: progress.availableBytes))
                NotificationCenter.default.post(
                    name: .storageAnalysisDidFetchBasicInfo,
                    object: nil,
                    userInfo: ["totalBytes": progress.totalDeviceBytes, "availableBytes": progress.availableBytes]
                )
            }
        } catch {
            print("[StorageAnalysis] ERROR fetching device storage: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.setCurrentState(.error(error))
                NotificationCenter.default.post(name: .storageAnalysisDidFail, object: nil, userInfo: ["error": error])
            }
            return
        }

        print("[StorageAnalysis] Checking photo library authorization...")
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        var finalAuthStatus = authStatus
        if authStatus == .notDetermined {
            print("[StorageAnalysis] Authorization not determined, requesting permission...")
            let semaphore = DispatchSemaphore(value: 0)
            var requestedStatus: PHAuthorizationStatus = .notDetermined

            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                requestedStatus = status
                semaphore.signal()
            }

            semaphore.wait()
            finalAuthStatus = requestedStatus
            print("[StorageAnalysis] Authorization result: \(finalAuthStatus.rawValue)")
        } else {
            print("[StorageAnalysis] Authorization status: \(authStatus.rawValue)")
        }

        guard finalAuthStatus == .authorized || finalAuthStatus == .limited else {
            print("[StorageAnalysis] Photo library access not granted.")
            let analysisData = StorageAnalysisData(
                photosCount: 0, photosBytes: 0,
                videosCount: 0, videosBytes: 0,
                totalDeviceBytes: progress.totalDeviceBytes,
                availableBytes: progress.availableBytes,
                lastAnalysisDate: Date()
            )
            DispatchQueue.main.async { [weak self] in
                self?.saveCachedData(analysisData)
                self?.setCurrentState(.loaded(analysisData))
                self?.clearProgress()
                NotificationCenter.default.post(
                    name: .storageAnalysisDidComplete, object: nil, userInfo: ["data": analysisData])
            }
            return
        }

        // Warmup fetch makes plist readable
        let warmupOptions = PHFetchOptions()
        warmupOptions.fetchLimit = 1
        _ = PHAsset.fetchAssets(with: warmupOptions)

        if Self.checkICloudPhotosSyncStatus() {
            let analysisData = StorageAnalysisData(
                photosCount: 0, photosBytes: 0,
                videosCount: 0, videosBytes: 0,
                totalDeviceBytes: progress.totalDeviceBytes,
                availableBytes: progress.availableBytes,
                lastAnalysisDate: Date(),
                iCloudPhotosSyncOn: true
            )
            DispatchQueue.main.async { [weak self] in
                self?.saveCachedData(analysisData)
                self?.setCurrentState(.loaded(analysisData))
                self?.clearProgress()
                self?.setIsAnalysisRunning(false)
                self?.endUIBackgroundTask()
                self?.endLiveActivityIfAvailable(showComplete: true)
                NotificationCenter.default.post(
                    name: .storageAnalysisDidComplete, object: nil, userInfo: ["data": analysisData])
            }
            return
        }

        var detectedICloud = progress.iCloudPhotosSyncOn

        if !progress.isPhotosComplete {
            processAssets(
                phase: .photos, progress: &progress, startTime: startTime,
                detectedICloud: &detectedICloud, sessionId: sessionId)
            if isCancelled || sessionId != activeSessionId { return }
        }

        if !progress.isVideosComplete {
            processAssets(
                phase: .videos, progress: &progress, startTime: startTime,
                detectedICloud: &detectedICloud, sessionId: sessionId)
            if isCancelled || sessionId != activeSessionId { return }
        }

        progress.iCloudPhotosSyncOn = detectedICloud

        completeAnalysis(progress: progress, startTime: startTime, detectedICloud: detectedICloud, sessionId: sessionId)
    }

    func handlePause(progress: StorageAnalysisProgress, sessionId: Int) {
        guard sessionId == activeSessionId else {
            print("[StorageAnalysis] Skipping pause — session \(sessionId) superseded by \(activeSessionId)")
            return
        }

        print("[StorageAnalysis] Analysis paused. Progress saved.")
        saveProgress(progress)
        setIsAnalysisRunning(false)

        endUIBackgroundTask()
        endLiveActivityIfAvailable(showComplete: false)

        DispatchQueue.main.async { [weak self] in
            let totalOriginalBytes = progress.totalOriginalPhotosBytes + progress.totalOriginalVideosBytes

            let partialData = StorageAnalysisData(
                photosCount: progress.photosProcessedCount,
                photosBytes: progress.photosBytes,
                videosCount: progress.videosProcessedCount,
                videosBytes: progress.videosBytes,
                totalDeviceBytes: progress.totalDeviceBytes,
                availableBytes: progress.availableBytes,
                lastAnalysisDate: Date(),
                isPartial: true,
                progressPercentage: progress.overallProgress,
                iCloudPhotosSyncOn: progress.iCloudPhotosSyncOn,
                photosInCloudOnlyCount: progress.photosInCloudOnlyCount,
                photosInCloudOnlyBytes: progress.photosInCloudOnlyBytes,
                videosInCloudOnlyCount: progress.videosInCloudOnlyCount,
                videosInCloudOnlyBytes: progress.videosInCloudOnlyBytes,
                totalOriginalBytes: totalOriginalBytes
            )
            self?.setCurrentState(.loaded(partialData))
            self?.saveCachedData(partialData)
            NotificationCenter.default.post(
                name: .storageAnalysisDidPause,
                object: nil,
                userInfo: ["data": partialData, "progress": progress.overallProgress]
            )
        }
    }

    private func processAssets(
        phase: StorageAnalysisAttributes.AnalysisPhase,
        progress: inout StorageAnalysisProgress,
        startTime: Date,
        detectedICloud: inout Bool,
        sessionId: Int
    ) {
        let mediaType: PHAssetMediaType
        let fullSizeType: PHAssetResourceType
        let standardType: PHAssetResourceType
        let label: String

        switch phase {
        case .photos:
            mediaType = .image
            fullSizeType = .fullSizePhoto
            standardType = .photo
            label = "photos"
        case .videos:
            mediaType = .video
            fullSizeType = .fullSizeVideo
            standardType = .video
            label = "videos"
        case .complete:
            return
        }

        print("[StorageAnalysis] Processing \(label)...")
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)
        let assets = PHAsset.fetchAssets(with: fetchOptions)

        let startIndex: Int
        switch phase {
        case .photos:
            progress.photosTotalCount = assets.count
            startIndex = progress.lastProcessedPhotoIndex + 1
        case .videos:
            progress.videosTotalCount = assets.count
            startIndex = progress.lastProcessedVideoIndex + 1
        case .complete:
            return
        }
        print("[StorageAnalysis] \(label.capitalized): \(assets.count) total, resuming from index \(startIndex)")

        var processedInChunk = 0
        let chunkSize = 500

        for index in startIndex ..< assets.count {
            if isCancelled || sessionId != activeSessionId {
                print("[StorageAnalysis] Cancelled during \(label) processing [session \(sessionId)]")
                handlePause(progress: progress, sessionId: sessionId)
                return
            }

            autoreleasepool {
                let asset = assets.object(at: index)
                let resources = PHAssetResource.assetResources(for: asset)

                var assetLocalBytes: Int64 = 0
                var hasLocalResource = false
                var hasCloudOnlyResource = false

                var countedPrimary = false
                var primarySize: Int64 = 0
                var fullSizePairedVideoBytes: Int64 = 0
                var pairedVideoBytes: Int64 = 0

                for resource in resources {
                    if let size = resource.value(forKey: "fileSize") as? Int64, size > 0 {
                        let locallyAvailable = resource.value(forKey: "locallyAvailable") as? Bool

                        if locallyAvailable == true {
                            assetLocalBytes += size
                            hasLocalResource = true
                        } else if locallyAvailable == false {
                            hasCloudOnlyResource = true
                            detectedICloud = true
                        } else {
                            assetLocalBytes += size
                            hasLocalResource = true
                        }

                        if resource.type == fullSizeType {
                            primarySize = size
                            countedPrimary = true
                        } else if resource.type == standardType && !countedPrimary {
                            primarySize = size
                            countedPrimary = true
                        }

                        // Track paired video sizes - Live Photos only
                        if phase == .photos {
                            if resource.type == .fullSizePairedVideo {
                                fullSizePairedVideoBytes += size
                            } else if resource.type == .pairedVideo {
                                pairedVideoBytes += size
                            }
                        }
                    }
                }

                var assetOriginalBytes = primarySize
                if phase == .photos {
                    assetOriginalBytes += fullSizePairedVideoBytes > 0 ? fullSizePairedVideoBytes : pairedVideoBytes
                }

                switch phase {
                case .photos:
                    progress.photosBytes += assetLocalBytes
                    progress.totalOriginalPhotosBytes += assetOriginalBytes
                    if !hasLocalResource && hasCloudOnlyResource {
                        progress.photosInCloudOnlyCount += 1
                        progress.photosInCloudOnlyBytes += primarySize
                    }
                    progress.photosProcessedCount += 1
                    progress.lastProcessedPhotoIndex = index
                case .videos:
                    progress.videosBytes += assetLocalBytes
                    progress.totalOriginalVideosBytes += assetOriginalBytes
                    if !hasLocalResource && hasCloudOnlyResource {
                        progress.videosInCloudOnlyCount += 1
                        progress.videosInCloudOnlyBytes += primarySize
                    }
                    progress.videosProcessedCount += 1
                    progress.lastProcessedVideoIndex = index
                case .complete:
                    break
                }
                processedInChunk += 1
            }

            if processedInChunk >= chunkSize {
                processedInChunk = 0
                progress.sessionDate = Date()
                saveProgress(progress)

                let overallPct = Int(progress.overallProgress * 100)
                let elapsed = Date().timeIntervalSince(startTime)
                let processedCount = phase == .photos ? progress.photosProcessedCount : progress.videosProcessedCount
                let localBytes = phase == .photos ? progress.photosBytes : progress.videosBytes
                print(
                    "[StorageAnalysis] Checkpoint: \(overallPct)% at \(String(format: "%.1f", elapsed))s - \(processedCount) \(label) (\(localBytes.formattedBytes()))"
                )

                iCloudSyncLogger.shared.logAnalysisCheckpoint(
                    processed: progress.photosProcessedCount + progress.videosProcessedCount,
                    total: progress.photosTotalCount + progress.videosTotalCount,
                    localBytes: progress.photosBytes + progress.videosBytes,
                    cloudOnlyCount: progress.photosInCloudOnlyCount + progress.videosInCloudOnlyCount
                )

                updateLiveActivityIfAvailable(progress: progress, phase: phase)

                let currentCount = processedCount
                let totalCount = phase == .photos ? progress.photosTotalCount : progress.videosTotalCount
                let phaseRawValue = phase.rawValue
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .storageAnalysisDidUpdateProgress,
                        object: nil,
                        userInfo: [
                            "phase": phaseRawValue,
                            "progress": overallPct,
                            "current": currentCount,
                            "total": totalCount
                        ]
                    )
                }
            }
        }

        switch phase {
        case .photos:
            progress.isPhotosComplete = true
            saveProgress(progress)
            updateLiveActivityIfAvailable(progress: progress, phase: .videos)
        case .videos:
            progress.isVideosComplete = true
            saveProgress(progress)
        case .complete:
            break
        }

        let completedCount = phase == .photos ? progress.photosProcessedCount : progress.videosProcessedCount
        let completedBytes = phase == .photos ? progress.photosBytes : progress.videosBytes
        print(
            "[StorageAnalysis] \(label.capitalized) complete: \(completedCount) items, \(completedBytes.formattedBytes())"
        )
    }

    private func completeAnalysis(
        progress: StorageAnalysisProgress, startTime: Date, detectedICloud: Bool, sessionId: Int
    ) {
        guard sessionId == activeSessionId else {
            print("[StorageAnalysis] Skipping completion — session \(sessionId) superseded by \(activeSessionId)")
            return
        }

        let totalElapsed = Date().timeIntervalSince(startTime)
        print("[StorageAnalysis] COMPLETE in \(String(format: "%.1f", totalElapsed))s [session \(sessionId)]")
        print("[StorageAnalysis] Summary:")
        print("[StorageAnalysis]   Photos: \(progress.photosProcessedCount) items")
        print("[StorageAnalysis]     - On device: \(progress.photosBytes.formattedBytes())")
        print(
            "[StorageAnalysis]     - iCloud only: \(progress.photosInCloudOnlyCount) items (\(progress.photosInCloudOnlyBytes.formattedBytes()))"
        )
        print("[StorageAnalysis]     - Total original: \(progress.totalOriginalPhotosBytes.formattedBytes())")
        print("[StorageAnalysis]   Videos: \(progress.videosProcessedCount) items")
        print("[StorageAnalysis]     - On device: \(progress.videosBytes.formattedBytes())")
        print(
            "[StorageAnalysis]     - iCloud only: \(progress.videosInCloudOnlyCount) items (\(progress.videosInCloudOnlyBytes.formattedBytes()))"
        )
        print("[StorageAnalysis]     - Total original: \(progress.totalOriginalVideosBytes.formattedBytes())")
        print("[StorageAnalysis]   iCloud enabled: \(detectedICloud)")

        let totalOriginalBytes = progress.totalOriginalPhotosBytes + progress.totalOriginalVideosBytes

        iCloudSyncLogger.shared.logStorageSummary(
            localPhotos: progress.photosBytes,
            localVideos: progress.videosBytes,
            cloudOnlyPhotos: progress.photosInCloudOnlyBytes,
            cloudOnlyVideos: progress.videosInCloudOnlyBytes,
            totalOriginal: totalOriginalBytes
        )

        iCloudSyncLogger.shared.logPerformance(
            operation: "StorageAnalysis",
            duration: totalElapsed,
            itemCount: progress.photosProcessedCount + progress.videosProcessedCount
        )

        let analysisData = StorageAnalysisData(
            photosCount: progress.photosProcessedCount,
            photosBytes: progress.photosBytes,
            videosCount: progress.videosProcessedCount,
            videosBytes: progress.videosBytes,
            totalDeviceBytes: progress.totalDeviceBytes,
            availableBytes: progress.availableBytes,
            lastAnalysisDate: Date(),
            iCloudPhotosSyncOn: detectedICloud,
            photosInCloudOnlyCount: progress.photosInCloudOnlyCount,
            photosInCloudOnlyBytes: progress.photosInCloudOnlyBytes,
            videosInCloudOnlyCount: progress.videosInCloudOnlyCount,
            videosInCloudOnlyBytes: progress.videosInCloudOnlyBytes,
            totalOriginalBytes: totalOriginalBytes
        )

        setIsAnalysisRunning(false)
        endUIBackgroundTask()
        endLiveActivityIfAvailable(showComplete: true)

        DispatchQueue.main.async { [weak self] in
            self?.saveCachedData(analysisData)
            self?.setCurrentState(.loaded(analysisData))
            self?.clearProgress()
            NotificationCenter.default.post(
                name: .storageAnalysisDidComplete, object: nil, userInfo: ["data": analysisData])
        }
    }
}

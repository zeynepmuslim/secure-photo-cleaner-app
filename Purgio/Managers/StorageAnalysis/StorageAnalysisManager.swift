//
//  StorageAnalysisManager.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import ActivityKit
import BackgroundTasks
import Photos
import UIKit

final class StorageAnalysisManager {
    static let shared = StorageAnalysisManager()

    private let defaults = UserDefaults.standard
    private let sessionIdKey = "storageAnalysisSessionId"
    private let iCloudSyncKey = "iCloudPhotosSyncOn"

    var iCloudPhotosSyncOn: Bool {
        defaults.bool(forKey: iCloudSyncKey)
    }

    private let storageQueue = DispatchQueue(label: "com.galary.StorageAnalysisManager.storage")
    private let cacheFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Purgio/storageAnalysisCache.json")
    }()
    private let progressFileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Purgio/storageAnalysisProgress.json")
    }()

    private let chunkSize = 500

    private let stateQueue = DispatchQueue(label: "com.purgio.analysisState")
    private var _isCancelled = false
    var isCancelled: Bool {
        get { stateQueue.sync { _isCancelled } }
        set { stateQueue.sync { _isCancelled = newValue } }
    }

    private(set) var activeSessionId: Int = 0

    private(set) var currentState: StorageAnalysisState = .idle
    private(set) var cachedData: StorageAnalysisData?
    private(set) var currentProgress: StorageAnalysisProgress?

    private var lastAnalysisAttempt: Date?
    private var tempBasicInfo: (total: Int64, available: Int64)?

    // MARK: - Live Activity Storage
    private var currentActivityStorage: Any?

    @available(iOS 16.2, *)
    var currentActivity: Activity<StorageAnalysisAttributes>? {
        get { currentActivityStorage as? Activity<StorageAnalysisAttributes> }
        set { currentActivityStorage = newValue }
    }

    var currentSessionId: String {
        get { defaults.string(forKey: sessionIdKey) ?? UUID().uuidString }
        set { defaults.set(newValue, forKey: sessionIdKey) }
    }

    // MARK: - Background Task State
    private var _isAnalysisRunning = false
    private(set) var isAnalysisRunning: Bool {
        get { stateQueue.sync { _isAnalysisRunning } }
        set { stateQueue.sync { _isAnalysisRunning = newValue } }
    }
    var isInBackground = false
    var uiBackgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    private init() {
        try? FileManager.default.createDirectory(
            at: cacheFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        loadCachedData()
        loadProgress()
        setupAppLifecycleObservers()
        cleanupStaleActivities()
    }

    private func loadProgress() {
        guard let data = try? Data(contentsOf: progressFileURL) else {
            currentProgress = nil
            return
        }

        do {
            let progress = try JSONDecoder().decode(StorageAnalysisProgress.self, from: data)
            if Date().timeIntervalSince(progress.sessionDate) < 3600 {   // 1 hour protection
                currentProgress = progress
                print(
                    "[StorageAnalysis] Loaded saved progress: photos \(progress.photosProcessedCount)/\(progress.photosTotalCount), videos \(progress.videosProcessedCount)/\(progress.videosTotalCount)"
                )
            } else {
                print("[StorageAnalysis] Discarding stale progress (older than 1 hour)")
                clearProgress()
            }
        } catch {
            print("[StorageAnalysis] Failed to decode progress: \(error)")
            currentProgress = nil
        }
    }

    func saveProgress(_ progress: StorageAnalysisProgress) {
        currentProgress = progress
        let url = progressFileURL
        storageQueue.async {
            if let data = try? JSONEncoder().encode(progress) {
                try? data.write(to: url, options: [.atomic])
            } else {
                print("[StorageAnalysis] Failed to save progress")
            }
        }
    }

    func clearProgress() {
        currentProgress = nil
        let url = progressFileURL
        storageQueue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    var hasResumableProgress: Bool {   //if there's resumable progress available
        guard let progress = currentProgress else { return false }
        return !progress.isComplete && Date().timeIntervalSince(progress.sessionDate) < 3600
    }

    // MARK: - Cache Management
    private func loadCachedData() {
        guard let data = try? Data(contentsOf: cacheFileURL) else {
            currentState = .idle
            return
        }

        do {
            let analysisData = try JSONDecoder().decode(StorageAnalysisData.self, from: data)
            cachedData = analysisData

            if analysisData.isPartial {
                print("[StorageAnalysis] Loaded partial cached data - will resume on refresh")
                currentState = .idle
            } else {
                currentState = .loaded(analysisData)
            }
        } catch {
            print("Failed to decode cached storage analysis: \(error)")
            currentState = .idle
        }
    }

    func saveCachedData(_ data: StorageAnalysisData) {
        cachedData = data
        defaults.set(data.iCloudPhotosSyncOn, forKey: iCloudSyncKey)
        let url = cacheFileURL
        storageQueue.async {
            if let encoded = try? JSONEncoder().encode(data) {
                try? encoded.write(to: url, options: [.atomic])
            } else {
                print("Failed to encode storage analysis data")
            }
        }
    }

    func invalidateCache() {
        cachedData = nil
        currentState = .idle
        defaults.removeObject(forKey: iCloudSyncKey)
        let url = cacheFileURL
        storageQueue.async {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - iCloud Detection
    static func checkICloudPhotosSyncStatus() -> Bool {
        let syncPath = "/var/mobile/Media/PhotoData/CPL/syncstatus.plist"
        guard let dict = NSDictionary(contentsOfFile: syncPath) else {
            return false
        }
        let iCloudExists = dict["iCloudLibraryExists"] as? Int ?? 0
        let counts = dict["cloudAssetCountPerType"] as? [String: Any]
        let photoCount = counts?["public.image"] as? Int ?? 0
        let videoCount = counts?["public.movie"] as? Int ?? 0
        return iCloudExists == 1 && (photoCount > 0 || videoCount > 0)
    }

    /// Used/Available only
    func performBasicOnlyAnalysis() {
        lastAnalysisAttempt = Date()

        currentState = .loading
        NotificationCenter.default.post(name: .storageAnalysisDidStart, object: nil)

        do {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0

            let analysisData = StorageAnalysisData(
                photosCount: 0, photosBytes: 0,
                videosCount: 0, videosBytes: 0,
                totalDeviceBytes: total,
                availableBytes: available,
                lastAnalysisDate: Date(),
                iCloudPhotosSyncOn: true
            )

            saveCachedData(analysisData)
            clearProgress()
            currentState = .loaded(analysisData)
            NotificationCenter.default.post(
                name: .storageAnalysisDidComplete, object: nil, userInfo: ["data": analysisData])

        } catch {
            currentState = .error(error)
            NotificationCenter.default.post(name: .storageAnalysisDidFail, object: nil, userInfo: ["error": error])
        }
    }

    // MARK: - Analysis Control
    func refreshIfNeeded() {
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if authStatus == .notDetermined {
            print("[StorageAnalysis] Authorization not determined; skipping refreshIfNeeded.")
            return
        }

        if hasResumableProgress {
            print("[StorageAnalysis] Resuming incomplete analysis")
            resumeAnalysis()
            return
        }

        guard let data = cachedData else {
            startAnalysis()
            return
        }

        if data.isPartial {   // not hasResumableProgress but still half = old or broken
            print("[StorageAnalysis] Cached data is partial - starting fresh analysis")
            startAnalysis()
            return
        }

        if data.isStale {   // +7 day
            startAnalysis()
        }
    }

    func invalidateAndRefresh() {
        activeSessionId += 1
        let newSession = activeSessionId
        print("[StorageAnalysis] invalidateAndRefresh: session \(newSession)")

        //clear
        isCancelled = true
        isAnalysisRunning = false
        lastAnalysisAttempt = nil

        invalidateCache()
        clearProgress()

        // fresh start
        startAnalysis()

        do {
            let homeURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try homeURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let available = values.volumeAvailableCapacityForImportantUsage ?? 0

            if total > 0 {
                currentState = .loadingWithBasicInfo(totalBytes: total, availableBytes: available)
                NotificationCenter.default.post(
                    name: .storageAnalysisDidFetchBasicInfo,
                    object: nil,
                    userInfo: ["totalBytes": total, "availableBytes": available]
                )
            }
        } catch {
            print("[StorageAnalysis] Failed to fetch basic storage info: \(error)")
        }
    }

    func startAnalysis() {
        if currentState.isLoading || isAnalysisRunning {
            return
        }

        if let lastAttempt = lastAnalysisAttempt, Date().timeIntervalSince(lastAttempt) < 5 {
            print("[StorageAnalysis] Skipping analysis (cooldown active)")
            return
        }

        lastAnalysisAttempt = Date()
        isAnalysisRunning = true   //  performChunkedAnalysis() is handle isCancelled flag

        currentState = .loading
        NotificationCenter.default.post(name: .storageAnalysisDidStart, object: nil)

        startLiveActivityIfAvailable()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performChunkedAnalysis()
        }
    }

    func resumeAnalysis() {
        guard hasResumableProgress else {
            print("[StorageAnalysis] No resumable progress, starting fresh")
            startAnalysis()
            return
        }

        if currentState.isLoading || isAnalysisRunning {
            return
        }

        lastAnalysisAttempt = Date()
        isCancelled = false
        isAnalysisRunning = true
        currentState = .loading
        NotificationCenter.default.post(name: .storageAnalysisDidStart, object: nil)

        startLiveActivityIfAvailable()

        print("[StorageAnalysis] Resuming from saved progress")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.performChunkedAnalysis()
        }
    }

    func cancelAnalysis() {
        isCancelled = true
        isAnalysisRunning = false

        endUIBackgroundTask()
        endLiveActivityIfAvailable(showComplete: false)
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundTaskIdentifier)

        print("[StorageAnalysis] Analysis cancellation requested")
    }

    // MARK: - Internal Helpers

    func setCurrentState(_ state: StorageAnalysisState) {
        currentState = state
    }

    func setIsAnalysisRunning(_ value: Bool) {
        isAnalysisRunning = value
    }
}

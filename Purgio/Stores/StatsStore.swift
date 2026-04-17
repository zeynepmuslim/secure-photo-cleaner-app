//
//  StatsStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos

final class StatsStore {
    static let shared = StatsStore()

    private let lock = NSLock()
    private let storageQueue = DispatchQueue(label: "com.galary.StatsStore.storage")
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Purgio/stats.json")
    }()

    private struct StatsData: Codable {
        var photosReviewed: Int = 0
        var photosDeleted: Int = 0
        var videosReviewed: Int = 0
        var videosDeleted: Int = 0
        var spaceSavedBytes: Int64 = 0
    }

    private var data = StatsData()
    private var persistWorkItem: DispatchWorkItem?

    private init() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        if let fileData = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(StatsData.self, from: fileData)
        {
            data = decoded
        }
    }

    private func persistToDisk() {
        persistWorkItem?.cancel()
        let snapshot = lock.withLock { data }
        let url = fileURL
        let item = DispatchWorkItem {
            if let fileData = try? JSONEncoder().encode(snapshot) {
                try? fileData.write(to: url, options: [.atomic])
            }
        }
        persistWorkItem = item
        storageQueue.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    var photosReviewed: Int {
        get { lock.withLock { data.photosReviewed } }
        set {
            lock.withLock { data.photosReviewed = max(0, newValue) }
            persistToDisk()
        }
    }

    var photosDeleted: Int {
        get { lock.withLock { data.photosDeleted } }
        set {
            lock.withLock { data.photosDeleted = max(0, newValue) }
            persistToDisk()
        }
    }

    var videosReviewed: Int {
        get { lock.withLock { data.videosReviewed } }
        set {
            lock.withLock { data.videosReviewed = max(0, newValue) }
            persistToDisk()
        }
    }

    var videosDeleted: Int {
        get { lock.withLock { data.videosDeleted } }
        set {
            lock.withLock { data.videosDeleted = max(0, newValue) }
            persistToDisk()
        }
    }

    var spaceSavedBytes: Int64 {
        get { lock.withLock { data.spaceSavedBytes } }
        set {
            lock.withLock { data.spaceSavedBytes = max(0, newValue) }
            persistToDisk()
        }
    }

    // MARK: - Computed Properties
    var totalReviewed: Int {
        lock.withLock { data.photosReviewed + data.videosReviewed }
    }

    var totalDeleted: Int {
        lock.withLock { data.photosDeleted + data.videosDeleted }
    }

    var spaceSavedMB: Double {
        Double(lock.withLock { data.spaceSavedBytes }) / 1_048_576.0
    }

    var spaceSavedGB: Double {
        Double(lock.withLock { data.spaceSavedBytes }) / 1_073_741_824.0
    }

    func recordReview(for mediaType: PHAssetMediaType) {
        lock.withLock {
            switch mediaType {
            case .image:
                data.photosReviewed += 1
            case .video:
                data.videosReviewed += 1
            default:
                break
            }
        }
        persistToDisk()
    }

    func recordDeletion(for mediaType: PHAssetMediaType, bytes: Int64) {
        lock.withLock {
            switch mediaType {
            case .image:
                data.photosDeleted += 1
            case .video:
                data.videosDeleted += 1
            default:
                break
            }
            data.spaceSavedBytes += bytes
        }
        persistToDisk()
    }

    func undoReview(for mediaType: PHAssetMediaType) {
        lock.withLock {
            switch mediaType {
            case .image: data.photosReviewed = max(0, data.photosReviewed - 1)
            case .video: data.videosReviewed = max(0, data.videosReviewed - 1)
            default: break
            }
        }
        persistToDisk()
    }

    func undoDeletion(for mediaType: PHAssetMediaType, bytes: Int64) {
        lock.withLock {
            switch mediaType {
            case .image:
                data.photosDeleted = max(0, data.photosDeleted - 1)
            case .video:
                data.videosDeleted = max(0, data.videosDeleted - 1)
            default:
                break
            }
            data.spaceSavedBytes = max(0, data.spaceSavedBytes - bytes)
        }
        persistToDisk()
    }

    func resetAll() {
        lock.withLock { data = StatsData() }
        persistToDisk()
    }

    func formattedSpaceSaved() -> String {
        if spaceSavedGB >= 1.0 {
            return String(format: "%.2f GB", spaceSavedGB)
        } else {
            return String(format: "%.1f MB", spaceSavedMB)
        }
    }
}

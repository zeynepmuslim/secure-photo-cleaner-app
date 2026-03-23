//
//  ReviewProgressStore.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Foundation
import Photos

final class ReviewProgressStore {
    static let shared = ReviewProgressStore()
    
    private let storageQueue = DispatchQueue(label: "ReviewProgressStore.storage")
    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("SecurePhotoCleaner", isDirectory: true)
        return (dir ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("reviewProgress.json")
    }()
    private var cachedProgress: [String: MonthProgress]?
    
    private init() {
        storageQueue.async { [self] in
            _ = loadCacheIfNeeded()
        }
    }
    
    private struct MonthProgress: Codable {
        var currentIndex: Int
        var reviewedCount: Int
        var deletedCount: Int
        var keptCount: Int
        var storedCount: Int
        var originalTotalCount: Int
    }

    private func makeKey(monthKey: String, mediaType: PHAssetMediaType) -> String {
        let mediaPrefix = mediaType == .video ? "video_" : "photo_"
        return "\(mediaPrefix)\(monthKey)"
    }

    private func loadCacheIfNeeded() -> [String: MonthProgress] {
        if let cached = cachedProgress {
            return cached
        }

        let fileManager = FileManager.default
        if let dir = fileURL.deletingLastPathComponent() as URL? {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        }

        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: MonthProgress].self, from: data) else {
            cachedProgress = [:]
            return [:]
        }

        cachedProgress = decoded
        return decoded
    }

    private func persist(_ progress: [String: MonthProgress]) {
        cachedProgress = progress
        if let data = try? JSONEncoder().encode(progress) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
    
    func getProgress(forMonthKey monthKey: String, mediaType: PHAssetMediaType = .image) -> (currentIndex: Int, reviewedCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int, originalTotalCount: Int) {
        let key = makeKey(monthKey: monthKey, mediaType: mediaType)
        let result = storageQueue.sync {
            let progressDict = loadCacheIfNeeded()
            guard let progress = progressDict[key] else {
                return (0, 0, 0, 0, 0, 0)
            }
            return (progress.currentIndex, progress.reviewedCount, progress.deletedCount, progress.keptCount, progress.storedCount, progress.originalTotalCount)
        }
        return result
    }
    
    func saveProgress(forMonthKey monthKey: String, mediaType: PHAssetMediaType = .image, currentIndex: Int, reviewedCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int, originalTotalCount: Int) {
        let key = makeKey(monthKey: monthKey, mediaType: mediaType)
        storageQueue.async {
            var progressDict = self.loadCacheIfNeeded()
            progressDict[key] = MonthProgress(
                currentIndex: currentIndex,
                reviewedCount: reviewedCount,
                deletedCount: deletedCount,
                keptCount: keptCount,
                storedCount: storedCount,
                originalTotalCount: originalTotalCount
            )
            self.persist(progressDict)
        }
    }
    
    func batchSave(_ updates: [(monthKey: String, mediaType: PHAssetMediaType, currentIndex: Int, reviewedCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int, originalTotalCount: Int)]) {
        storageQueue.async {
            var progressDict = self.loadCacheIfNeeded()
            for update in updates {
                let key = self.makeKey(monthKey: update.monthKey, mediaType: update.mediaType)
                progressDict[key] = MonthProgress(
                    currentIndex: update.currentIndex,
                    reviewedCount: update.reviewedCount,
                    deletedCount: update.deletedCount,
                    keptCount: update.keptCount,
                    storedCount: update.storedCount,
                    originalTotalCount: update.originalTotalCount
                )
            }
            self.persist(progressDict)
        }
    }

    func markComplete(forMonthKey monthKey: String, mediaType: PHAssetMediaType = .image, totalCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int, originalTotalCount: Int) {
        saveProgress(forMonthKey: monthKey, mediaType: mediaType, currentIndex: totalCount, reviewedCount: totalCount, deletedCount: deletedCount, keptCount: keptCount, storedCount: storedCount, originalTotalCount: originalTotalCount)
    }
    
    func resetProgress(forMonthKey monthKey: String, mediaType: PHAssetMediaType = .image) {
        saveProgress(forMonthKey: monthKey, mediaType: mediaType, currentIndex: 0, reviewedCount: 0, deletedCount: 0, keptCount: 0, storedCount: 0, originalTotalCount: 0)
    }
    
    func getAllProgress() -> [String: (currentIndex: Int, reviewedCount: Int, deletedCount: Int, keptCount: Int, storedCount: Int, originalTotalCount: Int)] {
        return storageQueue.sync {
            let progressDict = loadCacheIfNeeded()
            return progressDict.mapValues {
                (currentIndex: $0.currentIndex, reviewedCount: $0.reviewedCount, deletedCount: $0.deletedCount, keptCount: $0.keptCount, storedCount: $0.storedCount, originalTotalCount: $0.originalTotalCount)
            }
        }
    }
}

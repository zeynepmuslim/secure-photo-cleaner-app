//
//  StorageAnalysisProgress.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 31.01.2026.
//

import Foundation

struct StorageAnalysisProgress: Codable {
    var photosProcessedCount: Int
    var photosBytes: Int64
    var photosTotalCount: Int
    var videosProcessedCount: Int
    var videosBytes: Int64
    var videosTotalCount: Int
    var totalDeviceBytes: Int64
    var availableBytes: Int64
    var isPhotosComplete: Bool
    var isVideosComplete: Bool
    var lastProcessedPhotoIndex: Int
    var lastProcessedVideoIndex: Int
    var sessionDate: Date

    // iCloud tracking
    var iCloudPhotosSyncOn: Bool
    var photosInCloudOnlyCount: Int
    var photosInCloudOnlyBytes: Int64
    var videosInCloudOnlyCount: Int
    var videosInCloudOnlyBytes: Int64
    var totalOriginalPhotosBytes: Int64
    var totalOriginalVideosBytes: Int64

    var isComplete: Bool {
        isPhotosComplete && isVideosComplete
    }

    var overallProgress: Double {
        let totalItems = photosTotalCount + videosTotalCount
        guard totalItems > 0 else { return 0 }
        let processedItems = (isPhotosComplete ? photosTotalCount : photosProcessedCount) +
                            (isVideosComplete ? videosTotalCount : videosProcessedCount)
        return Double(processedItems) / Double(totalItems)
    }

    static func fresh() -> StorageAnalysisProgress {
        StorageAnalysisProgress(
            photosProcessedCount: 0,
            photosBytes: 0,
            photosTotalCount: 0,
            videosProcessedCount: 0,
            videosBytes: 0,
            videosTotalCount: 0,
            totalDeviceBytes: 0,
            availableBytes: 0,
            isPhotosComplete: false,
            isVideosComplete: false,
            lastProcessedPhotoIndex: -1,
            lastProcessedVideoIndex: -1,
            sessionDate: Date(),
            iCloudPhotosSyncOn: false,
            photosInCloudOnlyCount: 0,
            photosInCloudOnlyBytes: 0,
            videosInCloudOnlyCount: 0,
            videosInCloudOnlyBytes: 0,
            totalOriginalPhotosBytes: 0,
            totalOriginalVideosBytes: 0
        )
    }
}

enum StorageAnalysisState {
    case idle
    case loading
    case loadingWithBasicInfo(totalBytes: Int64, availableBytes: Int64)
    case loaded(StorageAnalysisData)
    case error(Error)

    var isLoading: Bool {
        switch self {
        case .loading, .loadingWithBasicInfo:
            return true
        default:
            return false
        }
    }
}

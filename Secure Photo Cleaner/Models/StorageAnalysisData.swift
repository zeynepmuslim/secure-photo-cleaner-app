//
//  StorageAnalysisData.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Foundation

struct StorageAnalysisData: Codable {
    let photosCount: Int
    let photosBytes: Int64
    let videosCount: Int
    let videosBytes: Int64
    let totalDeviceBytes: Int64
    let availableBytes: Int64
    let lastAnalysisDate: Date

    var isPartial: Bool = false
    var progressPercentage: Double?

    // MARK: - iCloud Storage Data
    var iCloudPhotosSyncOn: Bool = false
    var photosInCloudOnlyCount: Int = 0
    var photosInCloudOnlyBytes: Int64 = 0
    var videosInCloudOnlyCount: Int = 0
    var videosInCloudOnlyBytes: Int64 = 0
    var totalOriginalBytes: Int64 = 0

    init(
        photosCount: Int,
        photosBytes: Int64,
        videosCount: Int,
        videosBytes: Int64,
        totalDeviceBytes: Int64,
        availableBytes: Int64,
        lastAnalysisDate: Date,
        isPartial: Bool = false,
        progressPercentage: Double? = nil,
        iCloudPhotosSyncOn: Bool = false,
        photosInCloudOnlyCount: Int = 0,
        photosInCloudOnlyBytes: Int64 = 0,
        videosInCloudOnlyCount: Int = 0,
        videosInCloudOnlyBytes: Int64 = 0,
        totalOriginalBytes: Int64 = 0
    ) {
        self.photosCount = photosCount
        self.photosBytes = photosBytes
        self.videosCount = videosCount
        self.videosBytes = videosBytes
        self.totalDeviceBytes = totalDeviceBytes
        self.availableBytes = availableBytes
        self.lastAnalysisDate = lastAnalysisDate
        self.isPartial = isPartial
        self.progressPercentage = progressPercentage
        self.iCloudPhotosSyncOn = iCloudPhotosSyncOn
        self.photosInCloudOnlyCount = photosInCloudOnlyCount
        self.photosInCloudOnlyBytes = photosInCloudOnlyBytes
        self.videosInCloudOnlyCount = videosInCloudOnlyCount
        self.videosInCloudOnlyBytes = videosInCloudOnlyBytes
        self.totalOriginalBytes = totalOriginalBytes
    }

    // MARK: - Computed Properties
    var isStale: Bool {
        let daysSinceAnalysis = Calendar.current.dateComponents([.day], from: lastAnalysisDate, to: Date()).day ?? 0
        return daysSinceAnalysis >= 7
    }

    var totalMediaBytes: Int64 {
        photosBytes + videosBytes
    }

    var usedBytes: Int64 {
        totalDeviceBytes - availableBytes
    }

    var otherBytes: Int64 {
        max(0, usedBytes - photosBytes - videosBytes)
    }

    // MARK: - iCloud Computed Properties

    var totalCloudOnlyBytes: Int64 {
        photosInCloudOnlyBytes + videosInCloudOnlyBytes
    }

    var totalCloudOnlyCount: Int {
        photosInCloudOnlyCount + videosInCloudOnlyCount
    }

    var hasCloudOnlyItems: Bool {
        totalCloudOnlyCount > 0
    }

    var cloudOnlyPercentage: Double {
        guard totalOriginalBytes > 0 else { return 0 }
        return Double(totalCloudOnlyBytes) / Double(totalOriginalBytes) * 100
    }

    var localPhotosBytes: Int64 {
        photosBytes
    }

    var localVideosBytes: Int64 {
        videosBytes
    }

    var totalLocalMediaBytes: Int64 {
        photosBytes + videosBytes
    }

    // MARK: - Freshness Indicator
    enum Freshness {
        case fresh      // < 1 day
        case recent     // 1-6 days
        case stale      // 7+ days
    }

    var freshness: Freshness {
        let daysSinceAnalysis = Calendar.current.dateComponents([.day], from: lastAnalysisDate, to: Date()).day ?? 0
        if daysSinceAnalysis < 1 {
            return .fresh
        } else if daysSinceAnalysis < 7 {
            return .recent
        } else {
            return .stale
        }
    }

    // MARK: - Formatted Last Analysis Time
    var formattedLastAnalysis: String {
        let days = Calendar.current.dateComponents([.day], from: lastAnalysisDate, to: Date()).day ?? 0
        if days >= 7 {
            return NSLocalizedString("timeAgo.sevenPlusDays", comment: "7+ days ago")
        }
        return lastAnalysisDate.timeAgo()
    }
}

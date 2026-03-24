//
//  DashboardCardManager.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 27.01.2026.
//

import Photos
import UIKit

final class DashboardCardManager {
    static let shared = DashboardCardManager()

    private let statsStore = StatsStore.shared
    private let progressStore = ReviewProgressStore.shared
    private let photoLibraryService = PhotoLibraryService.shared
    private let storageManager = StorageAnalysisManager.shared

    private var cachedGalleryContext: GalleryContext?
    private var lastContextRefresh: Date?
    private let contextCacheDuration: TimeInterval = 300   // 5 minutes

    private let cardContentCacheKey = "cachedDashboardCardContent"
    private(set) var cachedCardContent: DashboardCardContent?

    private let hasGeneratedCardKey = "hasGeneratedDashboardCard"

    var hasEverGeneratedContent: Bool {
        #if DEBUG
            let value = UserDefaults.standard.bool(forKey: hasGeneratedCardKey)
//            print("[DashboardCardManager] hasEverGeneratedContent: \(value)")
            return value
        #else
            return UserDefaults.standard.bool(forKey: hasGeneratedCardKey)
        #endif
    }

    private var lastMotivationIndex: Int?
    private var lastActionIndex: Int?
    private var lastAnalyticsIndex: Int?

    private let motivationCardWeight: Int = 60
    private let resumeCardWeight: Int = 25
    private let analyticsCardWeight: Int = 25

    private init() {}

    struct GalleryContext {
        let oldestYear: String?
        let oldestUnfinishedYear: String?
        let newestYear: String?
        let lastMonth: String?
        let randomMonth: String?
        let randomRecentMonth: String?
        let totalPhotosCount: Int
        let totalVideosCount: Int
        let monthBuckets: [String]

        static let empty = GalleryContext(
            oldestYear: nil,
            oldestUnfinishedYear: nil,
            newestYear: nil,
            lastMonth: nil,
            randomMonth: nil,
            randomRecentMonth: nil,
            totalPhotosCount: 0,
            totalVideosCount: 0,
            monthBuckets: []
        )
    }

    struct AnalyticsData {
        let photosReviewed: Int
        let photosDeleted: Int
        let videosReviewed: Int
        let videosDeleted: Int
        let totalSavedBytes: Int64

        var totalReviewed: Int { photosReviewed + videosReviewed }
        var totalDeleted: Int { photosDeleted + videosDeleted }

        var formattedTotalSaved: String {
            let gb = Double(totalSavedBytes) / 1_073_741_824.0
            let mb = Double(totalSavedBytes) / 1_048_576.0

            if gb >= 1.0 {
                return String(format: "%.2f GB", gb)
            } else if mb >= 0.1 {
                return String(format: "%.1f MB", mb)
            } else {
                return "0 MB"
            }
        }

        static let empty = AnalyticsData(
            photosReviewed: 0,
            photosDeleted: 0,
            videosReviewed: 0,
            videosDeleted: 0,
            totalSavedBytes: 0
        )
    }

    func getCachedOrDefaultContent() -> DashboardCardContent {
        if let cached = cachedCardContent {
            return cached
        }
        
        return .defaultContent
    }

    func getAnalyticsData() -> AnalyticsData {
        return AnalyticsData(
            photosReviewed: statsStore.photosReviewed,
            photosDeleted: statsStore.photosDeleted,
            videosReviewed: statsStore.videosReviewed,
            videosDeleted: statsStore.videosDeleted,
            totalSavedBytes: statsStore.spaceSavedBytes
        )
    }

    func invalidateContext() {
        cachedGalleryContext = nil
        lastContextRefresh = nil
    }

    func getInProgressMonths() -> [InProgressMonthInfo] {
        let allProgress = progressStore.getAllProgress()
        var inProgress: [InProgressMonthInfo] = []

        for (key, progress) in allProgress {
            guard progress.originalTotalCount > 0,
                progress.reviewedCount > 0,
                progress.reviewedCount < progress.originalTotalCount
            else {
                continue
            }

            let mediaType: PHAssetMediaType
            let monthKey: String
            if key.hasPrefix("video_") {
                mediaType = .video
                monthKey = String(key.dropFirst("video_".count))
            } else if key.hasPrefix("photo_") {
                mediaType = .image
                monthKey = String(key.dropFirst("photo_".count))
            } else {
                mediaType = .image
                monthKey = key
            }

            guard isPlainMonthKey(monthKey) else { continue }

            let percent = Int((Double(progress.reviewedCount) / Double(progress.originalTotalCount)) * 100)

            inProgress.append(
                InProgressMonthInfo(
                    monthKey: monthKey,
                    mediaType: mediaType,
                    reviewedCount: progress.reviewedCount,
                    totalCount: progress.originalTotalCount,
                    percentComplete: percent
                ))
        }

        return inProgress.sorted { $0.monthKey > $1.monthKey }
    }

    func generateResumeCard() -> DashboardCardContent? {
        guard let inProgress = getInProgressMonths().randomElement() else {
            return nil
        }

        return DashboardCardContent.motivation(
            title: "Continue Where You Left Off",
            subtitle: inProgress.formattedProgress,
            action: .resumeMonth(monthKey: inProgress.monthKey, mediaType: inProgress.mediaType)
        )
    }
    
    func generateSmartCard() async -> DashboardCardContent {
        let analytics = getAnalyticsData()
        let hasInProgress = !getInProgressMonths().isEmpty
        let hasActivity = analytics.totalReviewed > 0

        enum CardType {
            case motivation
            case resume(DashboardCardContent)
            case analytics
        }

        var options: [(weight: Int, type: CardType)] = []

        options.append((weight: motivationCardWeight, type: .motivation))

        if hasInProgress, let resumeCard = generateResumeCard() {
            options.append((weight: resumeCardWeight, type: .resume(resumeCard)))
        }

        if hasActivity {
            options.append((weight: analyticsCardWeight, type: .analytics))
        }

        let totalWeight = options.reduce(0) { $0 + $1.weight }
        let randomValue = Int.random(in: 0 ..< totalWeight)

        var selectedType: CardType = .motivation
        var cumulative = 0
        for option in options {
            cumulative += option.weight
            if randomValue < cumulative {
                selectedType = option.type
                break
            }
        }

        let content: DashboardCardContent
        switch selectedType {
        case .motivation:
            content = await generateMotivationCard()
        case .resume(let card):
            content = card
        case .analytics:
            content = await generateAnalyticsCard()
        }

        cachedCardContent = content

        if !UserDefaults.standard.bool(forKey: hasGeneratedCardKey) {
            #if DEBUG
                print("[DashboardCardManager] Setting hasGeneratedCardKey to true")
            #endif
            UserDefaults.standard.set(true, forKey: hasGeneratedCardKey)
        }

        return content
    }

    func generateMotivationCard() async -> DashboardCardContent {
        let context = await getGalleryContext()

        let motivation = getNextMotivation()
        let suggestion = getNextActionSuggestion()

        return DashboardCardContent.motivation(
            title: motivation,
            subtitle: suggestion.message,
            action: suggestion.actionFactory(context)
        )
    }
    
    func generateAnalyticsCard() async -> DashboardCardContent {
        let data = getAnalyticsData()
        let context = await getGalleryContext()
        let minDeletedCountForAnalytics = 20
        let minSavedBytesForAnalytics: Int64 = 50 * 1_048_576

        if data.totalReviewed == 0 {
            return DashboardCardContent.analytics(
                title: "Your Impact",
                subtitle: "Start reviewing your photos and videos to see your impact here.",
                action: .browsePhotos
            )
        }

        if data.totalDeleted < minDeletedCountForAnalytics && data.totalSavedBytes < minSavedBytesForAnalytics {
            return await generateMotivationCard()
        }

        let subtitle =
            AnalyticsTemplate.generate(from: data)
            ?? "You've cleaned up \(data.totalDeleted) items, freeing \(data.formattedTotalSaved) of space."

        let action = suggestNextAction(from: context, analytics: data)

        return DashboardCardContent.analytics(
            title: "Your Impact",
            subtitle: subtitle,
            action: action
        )
    }

    func getGalleryContext() async -> GalleryContext {
        if let cached = cachedGalleryContext,
            let lastRefresh = lastContextRefresh,
            Date().timeIntervalSince(lastRefresh) < contextCacheDuration
        {
            return cached
        }

        let context = await buildGalleryContext()
        cachedGalleryContext = context
        lastContextRefresh = Date()
        return context
    }

    private func buildGalleryContext() async -> GalleryContext {
        async let photos = photoLibraryService.loadMonthBuckets(mediaType: .image)
        async let videos = photoLibraryService.loadMonthBuckets(mediaType: .video)

        let photoBuckets = await photos
        let videoBuckets = await videos

        return buildContextFromBuckets(photoBuckets: photoBuckets, videoBuckets: videoBuckets)
    }

    private func buildContextFromBuckets(
        photoBuckets: [PhotoLibraryService.MonthBucket],
        videoBuckets: [PhotoLibraryService.MonthBucket]
    ) -> GalleryContext {
        let allMonthKeys = (photoBuckets.map { $0.key } + videoBuckets.map { $0.key })
            .sorted()
        let uniqueMonthKeys = Array(Set(allMonthKeys)).sorted()

        let years = Set(uniqueMonthKeys.compactMap { $0.components(separatedBy: "-").first })
            .sorted()

        let oldestYear = years.first
        let newestYear = years.last
        let oldestUnfinishedYear = findOldestUnfinishedYear(in: photoBuckets, mediaType: .image)

        let lastMonth = uniqueMonthKeys.last

        let unfinishedPhotoMonths = photoBuckets.compactMap { bucket -> String? in
            let progress = progressStore.getProgress(forMonthKey: bucket.key, mediaType: .image)
            let total = progress.originalTotalCount > 0 ? progress.originalTotalCount : bucket.totalCount
            guard total > 0 else { return nil }
            return progress.reviewedCount < total ? bucket.key : nil
        }
        let randomMonth = unfinishedPhotoMonths.randomElement() ?? uniqueMonthKeys.randomElement()

        let recentMonths = Array(uniqueMonthKeys.suffix(12))
        let randomRecentMonth = recentMonths.randomElement()

        let totalPhotos = photoBuckets.reduce(0) { $0 + $1.totalCount }
        let totalVideos = videoBuckets.reduce(0) { $0 + $1.totalCount }

        return GalleryContext(
            oldestYear: oldestYear,
            oldestUnfinishedYear: oldestUnfinishedYear,
            newestYear: newestYear,
            lastMonth: lastMonth,
            randomMonth: randomMonth,
            randomRecentMonth: randomRecentMonth,
            totalPhotosCount: totalPhotos,
            totalVideosCount: totalVideos,
            monthBuckets: uniqueMonthKeys
        )
    }

    private func findOldestUnfinishedYear(
        in buckets: [PhotoLibraryService.MonthBucket],
        mediaType: PHAssetMediaType
    ) -> String? {
        var unfinishedYears = Set<String>()

        for bucket in buckets {
            guard let year = bucket.key.components(separatedBy: "-").first else { continue }
            let progress = progressStore.getProgress(forMonthKey: bucket.key, mediaType: mediaType)
            let total = progress.originalTotalCount > 0 ? progress.originalTotalCount : bucket.totalCount
            guard total > 0 else { continue }
            let isComplete = progress.reviewedCount >= total
            if !isComplete {
                unfinishedYears.insert(year)
            }
        }

        return unfinishedYears.sorted().first
    }

    private func getNextMotivation() -> String {
        let messages = MotivationMessages.messages
        let candidates = messages.indices.filter { $0 != lastMotivationIndex }
        let index = candidates.randomElement() ?? 0
        lastMotivationIndex = index
        return messages[index]
    }

    private func getNextActionSuggestion() -> ActionSuggestion {
        let suggestions = ActionSuggestion.suggestions
        let candidates = suggestions.indices.filter { $0 != lastActionIndex }
        let index = candidates.randomElement() ?? 0
        lastActionIndex = index
        return suggestions[index]
    }

    private func suggestNextAction(from context: GalleryContext, analytics: AnalyticsData) -> DashboardCardAction {
        if analytics.videosDeleted > analytics.photosDeleted * 2 {
            return .browsePhotos
        } else if analytics.photosDeleted > analytics.videosDeleted * 2 {
            return .browseVideos
        }

        return .viewSimilarPhotos(monthKey: context.randomRecentMonth)
    }

    func formatMonthKey(_ monthKey: String) -> String {
        return DateFormatterManager.shared.displayMonth(fromMonthKey: monthKey)
    }

    func formatYear(_ year: String) -> String {
        return year
    }

    private func isPlainMonthKey(_ monthKey: String) -> Bool {
        let parts = monthKey.split(separator: "-")
        guard parts.count == 2,
            parts[0].count == 4,
            parts[1].count == 2,
            parts[0].allSatisfy({ $0.isNumber }),
            parts[1].allSatisfy({ $0.isNumber })
        else {
            return false
        }
        return true
    }
}

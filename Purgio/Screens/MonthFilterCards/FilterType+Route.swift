//
//  FilterType+Route.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let similarTitle = NSLocalizedString("filterCards.similarTitle", comment: "Similar & Duplicated filter title")
    static let largestTitle = NSLocalizedString("filterCards.largestTitle", comment: "Largest first filter title")
    static let screenshotsTitle = NSLocalizedString("filterCards.screenshotsTitle", comment: "Screenshots filter title")
    static let eyesClosedTitle = NSLocalizedString("filterCards.eyesClosedTitle", comment: "Eyes closed filter title")
    static let screenRecTitle = NSLocalizedString("filterCards.screenRecTitle", comment: "Screen recordings filter title")
    static let slowMotionTitle = NSLocalizedString("filterCards.slowMotionTitle", comment: "Slow motion filter title")
    static let timeLapseTitle = NSLocalizedString("filterCards.timeLapseTitle", comment: "Time-lapse filter title")
    static let allPhotosTitle = NSLocalizedString("filterCards.allPhotosTitle", comment: "All photos filter title")
    static let allVideosTitle = NSLocalizedString("filterCards.allVideosTitle", comment: "All videos filter title")

    // Lowercase names for use inside a sentence: "No screenshots here"
    static let nameSimilar = NSLocalizedString("filterName.similar", comment: "Filter name inside a sentence: similar photos")
    static let nameScreenshots = NSLocalizedString("filterName.screenshots", comment: "Filter name inside a sentence: screenshots")
    static let nameLargePhotos = NSLocalizedString("filterName.largePhotos", comment: "Filter name inside a sentence: large photos")
    static let nameLargeVideos = NSLocalizedString("filterName.largeVideos", comment: "Filter name inside a sentence: large videos")
    static let nameEyesClosed = NSLocalizedString("filterName.eyesClosed", comment: "Filter name inside a sentence: photos with closed eyes")
    static let nameScreenRecordings = NSLocalizedString("filterName.screenRecordings", comment: "Filter name inside a sentence: screen recordings")
    static let nameSlowMotion = NSLocalizedString("filterName.slowMotion", comment: "Filter name inside a sentence: slow-motion videos")
    static let nameTimeLapse = NSLocalizedString("filterName.timeLapse", comment: "Filter name inside a sentence: time-lapse videos")
    static let namePhotos = NSLocalizedString("filterName.photos", comment: "Filter name inside a sentence: photos")
    static let nameVideos = NSLocalizedString("filterName.videos", comment: "Filter name inside a sentence: videos")

    static let continueReview = NSLocalizedString("filterCards.continue", comment: "Continue button before the items are counted")
    static func continueLeft(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("filterCards.continueLeft", comment: "Continue button with the number of items left"),
            count)
    }
}

/// What a month's filter looks like, how far along it is and which screen reviews it. The month
/// hub and the end states' "Keep going" list (`MonthNextStepsView`) both read it from here.
extension MonthFilterStatusStore.FilterType {

    // MARK: - Card

    /// The hub's order: the four filters in reading order, then All Photos / All Videos.
    static func hubOrder(for mediaType: PHAssetMediaType) -> [MonthFilterStatusStore.FilterType] {
        mediaType == .video
            ? [.slowMotion, .largeFiles, .timeLapse, .screenRecordings, .allContent]
            : [.similar, .largeFiles, .eyesClosed, .screenshots, .allContent]
    }

    func cardIcon(mediaType: PHAssetMediaType) -> String {
        switch self {
        case .allContent: return mediaType == .video ? "video" : "photo.on.rectangle"
        case .similar: return "photo.on.rectangle.angled"
        case .largeFiles: return "doc.text.magnifyingglass"
        case .screenshots: return "camera.viewfinder"
        case .eyesClosed: return "eye.slash.fill"
        case .screenRecordings: return "record.circle"
        case .slowMotion: return "speedometer"
        case .timeLapse: return "clock.arrow.circlepath"
        }
    }

    func cardTitle(mediaType: PHAssetMediaType) -> String {
        switch self {
        case .allContent: return mediaType == .video ? Strings.allVideosTitle : Strings.allPhotosTitle
        case .similar: return Strings.similarTitle
        case .largeFiles: return Strings.largestTitle
        case .screenshots: return Strings.screenshotsTitle
        case .eyesClosed: return Strings.eyesClosedTitle
        case .screenRecordings: return Strings.screenRecTitle
        case .slowMotion: return Strings.slowMotionTitle
        case .timeLapse: return Strings.timeLapseTitle
        }
    }

    func cardTint(mediaType: PHAssetMediaType) -> UIColor {
        switch self {
        case .allContent:
            return mediaType == .video ? FilterCard.CardColor.allVideos : FilterCard.CardColor.allPhotos
        case .largeFiles:
            return mediaType == .video ? FilterCard.CardColor.largestVideo : FilterCard.CardColor.largestPhoto
        case .similar: return FilterCard.CardColor.similar
        case .screenshots: return FilterCard.CardColor.screenshots
        case .eyesClosed: return FilterCard.CardColor.eyesClosed
        case .screenRecordings: return FilterCard.CardColor.screenRecordings
        case .slowMotion: return FilterCard.CardColor.slowMotion
        case .timeLapse: return FilterCard.CardColor.timeLapse
        }
    }

    /// The filter's name in lowercase, for the middle of a sentence.
    func sentenceName(mediaType: PHAssetMediaType) -> String {
        switch self {
        case .allContent: return mediaType == .video ? Strings.nameVideos : Strings.namePhotos
        case .similar: return Strings.nameSimilar
        case .largeFiles: return mediaType == .video ? Strings.nameLargeVideos : Strings.nameLargePhotos
        case .screenshots: return Strings.nameScreenshots
        case .eyesClosed: return Strings.nameEyesClosed
        case .screenRecordings: return Strings.nameScreenRecordings
        case .slowMotion: return Strings.nameSlowMotion
        case .timeLapse: return Strings.nameTimeLapse
        }
    }

    // MARK: - Status

    /// Complete when the whole month is, or when the filter's finished flag is set.
    func isComplete(monthKey: String, mediaType: PHAssetMediaType) -> Bool {
        if ReviewProgressStore.shared.isComplete(monthKey: monthKey, mediaType: mediaType) { return true }
        return MonthFilterStatusStore.shared.isFilterFinished(monthKey: monthKey, filter: self)
    }

    /// A card's capsule and status: a complete month completes every card; otherwise the finished
    /// flag wins over the filter's own progress record. All Photos and Largest First read the
    /// month's main record.
    func applyStatus(to card: FilterCard, monthKey: String, mediaType: PHAssetMediaType) {
        guard !ReviewProgressStore.shared.isComplete(monthKey: monthKey, mediaType: mediaType) else {
            card.setProgress(deleted: 0, kept: 0, stored: 0, total: 0, reviewed: 0, isFinished: true)
            return
        }
        let readsMainRecord = self == .allContent || self == .largeFiles
        let key = readsMainRecord ? monthKey : "\(monthKey)_\(rawValue)"
        let progress = ReviewProgressStore.shared.getProgress(forMonthKey: key, mediaType: mediaType)
        card.setProgress(
            deleted: progress.deletedCount,
            kept: progress.keptCount,
            stored: progress.storedCount,
            total: progress.originalTotalCount,
            reviewed: progress.reviewedCount,
            isFinished: MonthFilterStatusStore.shared.isFilterFinished(monthKey: monthKey, filter: self))
    }

    /// The end states' Continue, which resumes the month's All Photos deck: nil once the month is
    /// complete, "Continue" before its total is known, else "Continue · N left".
    static func continueTitle(monthKey: String, mediaType: PHAssetMediaType) -> String? {
        let store = ReviewProgressStore.shared
        guard !store.isComplete(monthKey: monthKey, mediaType: mediaType) else { return nil }
        let main = store.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        guard main.originalTotalCount > 0 else { return Strings.continueReview }
        return Strings.continueLeft(main.originalTotalCount - main.reviewedCount)
    }

    // MARK: - Route

    /// The deck's filter context; nil for Similar, which has its own screen.
    var filterContext: FilterContext? {
        switch self {
        case .allContent: return FilterContext.none
        case .similar: return nil
        case .largeFiles: return .largeFiles
        case .screenshots: return .screenshots
        case .eyesClosed: return .eyesClosed
        case .screenRecordings: return .screenRecordings
        case .slowMotion: return .slowMotion
        case .timeLapse: return .timeLapse
        }
    }

    init(filterContext: FilterContext) {
        switch filterContext {
        case .none: self = .allContent
        case .largeFiles: self = .largeFiles
        case .screenshots: self = .screenshots
        case .eyesClosed: self = .eyesClosed
        case .screenRecordings: self = .screenRecordings
        case .slowMotion: self = .slowMotion
        case .timeLapse: self = .timeLapse
        }
    }

    /// The screen that reviews this filter: Similar has its own, Largest First and Eyes Closed go
    /// through the processing screen, everything else is the deck. A year session hands over its
    /// preloaded assets (`yearAssets`); a month's screens fetch their own.
    func makeViewController(
        monthTitle: String, monthKey: String, mediaType: PHAssetMediaType,
        yearAssets: [PHAsset]? = nil, navigationSource: NavigationSource = .manual
    ) -> UIViewController {
        switch self {
        case .similar:
            let similar = SimilarPhotosViewController(
                assets: yearAssets, monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType)
            similar.navigationSource = navigationSource
            return similar
        case .largeFiles, .eyesClosed:
            let config: ProcessingConfig = self == .largeFiles ? .largeFiles() : .eyesClosed()
            let loading: ProcessingLoadingViewController
            if let yearAssets {
                loading = ProcessingLoadingViewController(
                    monthTitle: monthTitle, monthKey: monthKey, assets: yearAssets, mediaType: mediaType,
                    config: config)
            } else {
                loading = ProcessingLoadingViewController(
                    monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType, config: config)
            }
            loading.navigationSource = navigationSource
            return loading
        case .allContent, .screenshots, .screenRecordings, .slowMotion, .timeLapse:
            let review = MonthReviewViewController(
                monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType,
                filterContext: filterContext ?? FilterContext.none)
            if let yearAssets {
                review.setSortedAssets(yearAssets)
            }
            review.navigationSource = navigationSource
            return review
        }
    }
}

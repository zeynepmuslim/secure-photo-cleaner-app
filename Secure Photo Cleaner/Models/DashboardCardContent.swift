//
//  DashboardCardContent.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import Photos
import UIKit

enum DashboardCardType {
    case motivation
    case analytics
}

enum DashboardCardAction {
    case viewLargestVideos(monthKey: String?)
    case viewSimilarPhotos(monthKey: String?)
    case viewScreenshots(monthKey: String?)
    case viewOldestYear(year: String)
    case resumeMonth(monthKey: String, mediaType: PHAssetMediaType)
    case browsePhotos
    case browseVideos
    case none

    var buttonTitle: String {
        switch self {
        case .viewLargestVideos:
            return NSLocalizedString("dashboard.viewLargeVideos", comment: "View large videos button")
        case .viewSimilarPhotos:
            return NSLocalizedString("dashboard.browseSimilarPhotos", comment: "Browse similar photos button")
        case .viewScreenshots:
            return NSLocalizedString("dashboard.reviewScreenshots", comment: "Review screenshots button")
        case .viewOldestYear(let year):
            return String(format: NSLocalizedString("dashboard.startFromYear", comment: "Start from year button, e.g. 'Start from 2020'"), year)
        case .resumeMonth(let monthKey, _):
            return String(format: NSLocalizedString("dashboard.continueMonth", comment: "Continue month button, e.g. 'Continue January'"), Self.formatMonthKey(monthKey))
        case .browsePhotos:
            return NSLocalizedString("dashboard.browsePhotos", comment: "Browse photos button")
        case .browseVideos:
            return NSLocalizedString("dashboard.browseVideos", comment: "Browse videos button")
        case .none:
            return NSLocalizedString("dashboard.getStarted", comment: "Get started button")
        }
    }

    private static func formatMonthKey(_ monthKey: String) -> String {
        return DateFormatterManager.shared.displayMonth(fromMonthKey: monthKey)
    }
}

struct DashboardCardContent {
    let type: DashboardCardType
    let icon: String
    let iconColor: UIColor
    let title: String
    let subtitle: String
    let action: DashboardCardAction

    static var defaultContent: DashboardCardContent {
        let title = MotivationMessages.random()
        let suggestion = ActionSuggestion.random()
        return DashboardCardContent(
            type: .motivation,
            icon: "sparkles",
            iconColor: .systemBlue,
            title: title,
            subtitle: suggestion.message,
            action: .browsePhotos
        )
    }

    static func motivation(
        title: String,
        subtitle: String,
        action: DashboardCardAction
    ) -> DashboardCardContent {
        return DashboardCardContent(
            type: .motivation,
            icon: iconForAction(action),
            iconColor: colorForAction(action),
            title: title,
            subtitle: subtitle,
            action: action
        )
    }

    static func analytics(
        title: String,
        subtitle: String,
        action: DashboardCardAction = .browsePhotos
    ) -> DashboardCardContent {
        return DashboardCardContent(
            type: .analytics,
            icon: "chart.bar.fill",
            iconColor: .systemGreen,
            title: title,
            subtitle: subtitle,
            action: action
        )
    }

    private static func iconForAction(_ action: DashboardCardAction) -> String {
        switch action {
        case .viewLargestVideos:
            return "film.fill"
        case .viewSimilarPhotos:
            return "square.stack.3d.up.fill"
        case .viewScreenshots:
            return "rectangle.on.rectangle"
        case .viewOldestYear:
            return "clock.arrow.circlepath"
        case .resumeMonth:
            return "play.fill"
        case .browsePhotos:
            return "photo.fill"
        case .browseVideos:
            return "video.fill"
        case .none:
            return "sparkles"
        }
    }

    private static func colorForAction(_ action: DashboardCardAction) -> UIColor {
        switch action {
        case .viewLargestVideos:
            return .systemPurple
        case .viewSimilarPhotos:
            return .systemIndigo
        case .viewScreenshots:
            return .systemTeal
        case .viewOldestYear:
            return .systemOrange
        case .resumeMonth(_, let mediaType):
            return mediaType == .video ? .video100 : .photo100
        case .browsePhotos:
            return .photo100
        case .browseVideos:
            return .video100
        case .none:
            return .systemBlue
        }
    }
}

struct MotivationMessages {
    static let messages: [String] = [
        NSLocalizedString("motivation.catVideos", comment: "Motivation: make room for cat videos"),
        NSLocalizedString("motivation.newMemories", comment: "Motivation: make space for new memories"),
        NSLocalizedString("motivation.noSpace", comment: "Motivation: no space for next video"),
        NSLocalizedString("motivation.readyForCaptures", comment: "Motivation: storage ready for captures"),
        NSLocalizedString("motivation.perfectMoment", comment: "Motivation: space for perfect moment"),
        NSLocalizedString("motivation.memoriesOnTheWay", comment: "Motivation: new memories on the way"),
        NSLocalizedString("motivation.littleRoom", comment: "Motivation: make a little room"),
        NSLocalizedString("motivation.nextTrip", comment: "Motivation: before your next trip"),
        NSLocalizedString("motivation.storageFull", comment: "Motivation: avoid storage full"),
        NSLocalizedString("motivation.memoriesPileUp", comment: "Motivation: memories pile up"),
        NSLocalizedString("motivation.organizeGallery", comment: "Motivation: organize gallery"),
    ]

    static func random() -> String {
        messages.randomElement() ?? messages[0]
    }
}

struct ActionSuggestion {
    let message: String
    let actionFactory: (DashboardCardManager.GalleryContext) -> DashboardCardAction

    static let suggestions: [ActionSuggestion] = [
        ActionSuggestion(
            message: NSLocalizedString("suggestion.largestVideos", comment: "Suggestion: see largest videos"),
            actionFactory: { context in
                .viewLargestVideos(monthKey: context.lastMonth)
            }
        ),
        ActionSuggestion(
            message: NSLocalizedString("suggestion.similarPhotos", comment: "Suggestion: clean up similar photos"),
            actionFactory: { context in
                .viewSimilarPhotos(monthKey: context.randomRecentMonth)
            }
        ),
        ActionSuggestion(
            message: NSLocalizedString("suggestion.screenshots", comment: "Suggestion: review screenshots"),
            actionFactory: { context in
                .viewScreenshots(monthKey: context.randomMonth)
            }
        ),
        ActionSuggestion(
            message: NSLocalizedString("suggestion.oldestFiles", comment: "Suggestion: start with oldest files"),
            actionFactory: { context in
                .viewOldestYear(year: context.oldestUnfinishedYear ?? context.oldestYear ?? "2017")
            }
        ),
        ActionSuggestion(
            message: NSLocalizedString("suggestion.duplicateShots", comment: "Suggestion: clean up duplicates"),
            actionFactory: { context in
                .viewSimilarPhotos(monthKey: context.randomMonth)
            }
        )
    ]

    static func random() -> ActionSuggestion {
        suggestions.randomElement() ?? suggestions[0]
    }
}

struct AnalyticsTemplate {
    let messageFactory: (DashboardCardManager.AnalyticsData) -> String?

    static let templates: [AnalyticsTemplate] = [
        AnalyticsTemplate { data in
            guard data.totalSavedBytes > 0 else { return nil }
            return String(format: NSLocalizedString("analytics.freedUpSoFar", comment: "Analytics: freed up space so far"), data.formattedTotalSaved)
        },
        AnalyticsTemplate { data in
            guard data.photosDeleted > 0 || data.videosDeleted > 0 else { return nil }
            return String(format: NSLocalizedString("analytics.totalCleanup", comment: "Analytics: total cleanup summary"), data.photosDeleted, data.videosDeleted, data.formattedTotalSaved)
        },
        AnalyticsTemplate { data in
            guard data.totalSavedBytes > 0 else { return nil }
            let videosText = data.videosDeleted > 0
                ? String.localizedStringWithFormat(NSLocalizedString("analytics.videosCount", comment: "Video count for analytics"), data.videosDeleted)
                : ""
            let photosText = data.photosDeleted > 0
                ? String.localizedStringWithFormat(NSLocalizedString("analytics.photosCount", comment: "Photo count for analytics"), data.photosDeleted)
                : ""
            let combined = [photosText, videosText].filter { !$0.isEmpty }.joined(
                separator: " " + NSLocalizedString("analytics.and", comment: "And conjunction") + " ")
            guard !combined.isEmpty else { return nil }
            return String(format: NSLocalizedString("analytics.cleanedSaving", comment: "Analytics: cleaned items, saving space"), combined, data.formattedTotalSaved)
        },
        AnalyticsTemplate { data in
            guard data.totalDeleted > 0 else { return nil }
            return String(format: NSLocalizedString("analytics.itemsCleaned", comment: "Analytics: items cleaned and space saved"), data.totalDeleted, data.formattedTotalSaved)
        },
        AnalyticsTemplate { data in
            guard data.videosDeleted > data.photosDeleted else { return nil }
            return String(format: NSLocalizedString("analytics.biggestSpaceHogs", comment: "Analytics: videos are biggest space hogs"), data.formattedTotalSaved)
        },
        AnalyticsTemplate { data in
            guard data.totalReviewed > 0 else { return nil }
            return String(format: NSLocalizedString("analytics.reviewedAndFreed", comment: "Analytics: reviewed items and freed space"), data.totalReviewed, data.formattedTotalSaved)
        }
    ]

    static func generate(from data: DashboardCardManager.AnalyticsData) -> String? {
        let minDeletedCountForAnalytics = 20
        let minSavedBytesForAnalytics: Int64 = 50 * 1_048_576

        guard data.totalDeleted >= minDeletedCountForAnalytics || data.totalSavedBytes >= minSavedBytesForAnalytics
        else {
            return nil
        }

        let shuffled = templates.shuffled()
        for template in shuffled {
            if let message = template.messageFactory(data) {
                return message
            }
        }
        return nil
    }
}

struct InProgressMonthInfo {
    let monthKey: String
    let mediaType: PHAssetMediaType
    let reviewedCount: Int
    let totalCount: Int
    let percentComplete: Int

    var formattedMonth: String {
        return DateFormatterManager.shared.displayMonth(fromMonthKey: monthKey)
    }

    var formattedProgress: String {
        return "You left \(formattedMonth) at \(percentComplete)% (\(reviewedCount)/\(totalCount) reviewed)"
    }
}

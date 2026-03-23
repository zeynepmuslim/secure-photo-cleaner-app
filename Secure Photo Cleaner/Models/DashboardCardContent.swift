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
            return "View Large Videos"
        case .viewSimilarPhotos:
            return "Browse Similar Photos"
        case .viewScreenshots:
            return "Review Screenshots"
        case .viewOldestYear(let year):
            return "Start from \(year)"
        case .resumeMonth(let monthKey, _):
            return "Continue \(Self.formatMonthKey(monthKey))"
        case .browsePhotos:
            return "Browse Photos"
        case .browseVideos:
            return "Browse Videos"
        case .none:
            return "Get Started"
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
        "Make room to shoot more cat videos.",
        "Make space for new memories. Clear out the old ones.",
        "No space for your next video? Let's free some up.",
        "Is your storage ready for new captures?",
        "Make space for the next \"perfect moment.\"",
        "New memories might be on the way. Leave room for them.",
        "Shall we make a little room for new memories?",
        "Before your next trip, get both your suitcase and your gallery ready.",
        "So you don't have to see \"Storage Full\" again.",
        "Memories pile up — and so does clutter. It's time to sort them out.",
        "There's a lot to organize in your gallery. Let's get started."
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
            message: "Would you like to see the largest videos you recorded last month?",
            actionFactory: { context in
                .viewLargestVideos(monthKey: context.lastMonth)
            }
        ),
        ActionSuggestion(
            message: "Want to quickly clean up similar photos?",
            actionFactory: { context in
                .viewSimilarPhotos(monthKey: context.randomRecentMonth)
            }
        ),
        ActionSuggestion(
            message: "Would you like to review your screenshots in bulk?",
            actionFactory: { context in
                .viewScreenshots(monthKey: context.randomMonth)
            }
        ),
        ActionSuggestion(
            message: "Would you like to start with the oldest files in your gallery?",
            actionFactory: { context in
                .viewOldestYear(year: context.oldestUnfinishedYear ?? context.oldestYear ?? "2017")
            }
        ),
        ActionSuggestion(
            message: "Would you like to clean up duplicate shots in your gallery?",
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
            return "You've freed up \(data.formattedTotalSaved) so far."
        },
        AnalyticsTemplate { data in
            guard data.photosDeleted > 0 || data.videosDeleted > 0 else { return nil }
            return
                "Total cleanup: \(data.photosDeleted) photos, \(data.videosDeleted) videos, \(data.formattedTotalSaved) saved."
        },
        AnalyticsTemplate { data in
            guard data.totalSavedBytes > 0 else { return nil }
            let videosText = data.videosDeleted > 0 ? "\(data.videosDeleted) videos" : ""
            let photosText = data.photosDeleted > 0 ? "\(data.photosDeleted) photos" : ""
            let combined = [photosText, videosText].filter { !$0.isEmpty }.joined(separator: " and ")
            guard !combined.isEmpty else { return nil }
            return "You've cleaned \(combined), saving \(data.formattedTotalSaved)."
        },
        AnalyticsTemplate { data in
            guard data.totalDeleted > 0 else { return nil }
            return "Items cleaned: \(data.totalDeleted). Space saved: \(data.formattedTotalSaved)."
        },
        AnalyticsTemplate { data in
            guard data.videosDeleted > data.photosDeleted else { return nil }
            return "Biggest space hogs: Videos. You've freed \(data.formattedTotalSaved) so far."
        },
        AnalyticsTemplate { data in
            guard data.totalReviewed > 0 else { return nil }
            return "You've reviewed \(data.totalReviewed) items and freed \(data.formattedTotalSaved)."
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

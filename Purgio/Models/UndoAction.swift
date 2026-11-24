//
//  UndoAction.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Foundation
import UIKit

struct UndoAction: Codable {

    enum ActionType: String, Codable {
        case delete   // Marked for deletion
        case keep   // Kept the photo
        case store   // Will Be Stored
    }

    let id: UUID
    let actionType: ActionType
    let assetLocalIdentifier: String
    let index: Int
    let assetSize: Int64
    let timestamp: Date
    let sessionId: UUID

    var displayTitle: String { actionType.displayTitle }

    var displayIcon: String {
        switch actionType {
        case .delete:
            return "trash"
        case .keep:
            return "checkmark.circle"
        case .store:
            return "arrow.up.circle"
        }
    }

    var displayColor: UIColor { actionType.displayColor }
}

extension UndoAction.ActionType {

    /// What the action did, as the history rows and the detail sheet's title show it.
    var displayTitle: String {
        switch self {
        case .delete:
            return NSLocalizedString("undoAction.markedForDeletion", comment: "Undo action: marked for deletion")
        case .keep:
            return NSLocalizedString("undoAction.keptPhoto", comment: "Undo action: kept photo")
        case .store:
            return NSLocalizedString("undoAction.willBeStored", comment: "Undo action: will be stored")
        }
    }

    /// The action's color: the one source for the capsules and the detail sheet's segments.
    var displayColor: UIColor {
        switch self {
        case .delete: return ThemeManager.Colors.statusRed
        case .keep: return ThemeManager.Colors.statusGreen
        case .store: return ThemeManager.Colors.statusYellow
        }
    }

    /// The glyph color on the action's fill: black on yellow, white on red and green, in both
    /// appearances. The one source for the capsules, the detail sheet's chosen segment and the
    /// history toolbar's solid buttons.
    var displayInk: UIColor {
        self == .store ? .black : .white
    }
}

extension Date {
    func timeAgo() -> String {
        let seconds = Int(Date().timeIntervalSince(self))

        if seconds < 60 {
            return NSLocalizedString("timeAgo.justNow", comment: "Just now time label")
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return String.localizedStringWithFormat(NSLocalizedString("timeAgo.minutesAgo", comment: "Minutes ago, e.g. '5 minutes ago'"), minutes)
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return String.localizedStringWithFormat(NSLocalizedString("timeAgo.hoursAgo", comment: "Hours ago, e.g. '2 hours ago'"), hours)
        } else {
            let days = seconds / 86400
            return String.localizedStringWithFormat(NSLocalizedString("timeAgo.daysAgo", comment: "Days ago, e.g. '3 days ago'"), days)
        }
    }
}

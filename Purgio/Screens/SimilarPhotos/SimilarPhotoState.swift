//
//  SimilarPhotoState.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

/// What a photo in a similar set is marked as before the set is confirmed.
enum SimilarPhotoState {
    case keep
    case delete
    case store

    /// The thumbnail's border and badge, and the count chip's icon
    var color: UIColor {
        switch self {
        case .keep: return ThemeManager.Colors.statusGreen
        case .delete: return ThemeManager.Colors.statusRed
        case .store: return ThemeManager.Colors.statusYellow
        }
    }

    /// The glyph in a thumbnail's corner badge
    var badgeIcon: String {
        switch self {
        case .keep: return "checkmark"
        case .delete: return "xmark"
        case .store: return "archivebox.fill"
        }
    }

    /// The glyph of the set card's count chip
    var chipIcon: String {
        switch self {
        case .keep: return "checkmark"
        case .delete: return "trash"
        case .store: return "archivebox.fill"
        }
    }
}

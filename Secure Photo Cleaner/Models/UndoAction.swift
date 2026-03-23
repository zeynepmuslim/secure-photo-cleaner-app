//
//  UndoAction.swift
//  Secure Photo Cleaner
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

    var displayTitle: String {
        switch actionType {
        case .delete:
            return "Marked for Deletion"
        case .keep:
            return "Kept Photo"
        case .store:
            return "Will Be Stored"
        }
    }

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

    var displayColor: UIColor {
        switch actionType {
        case .delete:
            return .systemRed
        case .keep:
            return .systemGreen
        case .store:
            return .systemYellow
        }
    }
}

extension Date {
    func timeAgo() -> String {
        let seconds = Int(Date().timeIntervalSince(self))

        if seconds < 60 {
            return "Just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            let days = seconds / 86400
            return "\(days) day\(days == 1 ? "" : "s") ago"
        }
    }
}

//
//  MonthListModels.swift
//  Purgio
//
//  Created by ZeynepMüslim on 27.01.2026.
//

import Foundation

import Photos

struct MonthItem {
    let title: String
    let key: String
    let currentPhotoCount: Int
    let reviewedCount: Int
    let keptCount: Int
    let deletedCount: Int
    let storedCount: Int
    let originalTotalCount: Int
    let mediaType: PHAssetMediaType
}

struct YearSection {
    let year: String
    let months: [MonthItem]
}

enum FilterStatus: String, CaseIterable {
    case all = "All Statuses"
    case completed = "Completed"
    case inProgress = "In Progress"
    case notStarted = "Not Started"
}

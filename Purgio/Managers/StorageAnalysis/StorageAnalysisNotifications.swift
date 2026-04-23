//
//  StorageAnalysisNotifications.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import Foundation

extension Notification.Name {
    static let storageAnalysisDidStart = Notification.Name("storageAnalysisDidStart")
    static let storageAnalysisDidFetchBasicInfo = Notification.Name("storageAnalysisDidFetchBasicInfo")
    static let storageAnalysisDidUpdateProgress = Notification.Name("storageAnalysisDidUpdateProgress")
    static let storageAnalysisDidComplete = Notification.Name("storageAnalysisDidComplete")
    static let storageAnalysisDidFail = Notification.Name("storageAnalysisDidFail")
    static let storageAnalysisDidPause = Notification.Name("storageAnalysisDidPause")
}

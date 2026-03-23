//
//  iCloudSyncLogger.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 25.01.2026.
//

import Foundation
import Photos

final class iCloudSyncLogger {
    static let shared = iCloudSyncLogger()
    
    private init() {}
    
    private var shouldLog = false

    enum LogLevel: String {
        case info = "INFO"
        case warning = "WARN"
        case error = "ERROR"
        case security = "SECURITY"
        case performance = "PERF"
    }

    enum Category: String {
        case storage = "Storage"
        case download = "Download"
        case cache = "Cache"
        case network = "Network"
        case analysis = "Analysis"
        case security = "Security"
    }

    private var operationTimers: [String: Date] = [:]
    private let timerLock = NSLock()

    func startTimer(_ operationId: String) {
        timerLock.lock()
        defer { timerLock.unlock() }
        operationTimers[operationId] = Date()
    }

    func endTimer(_ operationId: String) -> TimeInterval? {
        timerLock.lock()
        defer { timerLock.unlock() }
        guard let start = operationTimers.removeValue(forKey: operationId) else { return nil }
        return Date().timeIntervalSince(start)
    }

    func log(_ category: Category, _ level: LogLevel, _ message: String, details: [String: Any]? = nil) {
        var output = "[iCloud:\(category.rawValue)] \(level.rawValue) | \(message)"

        if let details = details {
            let detailStr = details.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            output += " | \(detailStr)"
        }

        if shouldLog {
            print(output)
        }
    }

    // MARK: - Storage Accuracy Logging

    func logAssetSizeCalculation(assetId: String, localSize: Int64, originalSize: Int64, isCloudOnly: Bool) {
        log(.storage, .info, "Asset size calculated", details: [
            "assetId": truncateAssetId(assetId),
            "localSize": localSize.formattedBytes(),
            "originalSize": originalSize.formattedBytes(),
            "isCloudOnly": isCloudOnly
        ])
    }

    func logStorageSummary(localPhotos: Int64, localVideos: Int64, cloudOnlyPhotos: Int64, cloudOnlyVideos: Int64, totalOriginal: Int64) {
        log(.storage, .info, "Storage summary", details: [
            "localPhotos": localPhotos.formattedBytes(),
            "localVideos": localVideos.formattedBytes(),
            "cloudOnlyPhotos": cloudOnlyPhotos.formattedBytes(),
            "cloudOnlyVideos": cloudOnlyVideos.formattedBytes(),
            "totalOriginal": totalOriginal.formattedBytes()
        ])
    }

    func logStorageDiscrepancy(category: String, expected: Int64, actual: Int64) {
        log(.storage, .warning, "Storage discrepancy detected", details: [
            "category": category,
            "expected": expected.formattedBytes(),
            "actual": actual.formattedBytes(),
            "difference": abs(expected - actual).formattedBytes()
        ])
    }

    // MARK: - Download Events Logging

    func logDownloadStarted(assetId: String, estimatedSize: Int64, quality: String) {
        startTimer("download_\(assetId)")
        log(.download, .info, "Download started", details: [
            "assetId": truncateAssetId(assetId),
            "size": estimatedSize.formattedBytes(),
            "quality": quality
        ])
    }

    func logDownloadCompleted(assetId: String, success: Bool, wasDegraded: Bool) {
        let duration = endTimer("download_\(assetId)")
        log(.download, success ? .info : .warning, success ? "Download completed" : "Download returned degraded", details: [
            "assetId": truncateAssetId(assetId),
            "duration": duration.map { String(format: "%.2fs", $0) } ?? "unknown",
            "wasDegraded": wasDegraded
        ])
    }

    func logDownloadFailed(assetId: String, error: Error) {
        _ = endTimer("download_\(assetId)")
        log(.download, .error, "Download failed", details: [
            "assetId": truncateAssetId(assetId),
            "error": error.localizedDescription
        ])
    }

    func logDownloadProgress(assetId: String, progress: Double) {
        log(.download, .info, "Download progress", details: [
            "assetId": truncateAssetId(assetId),
            "progress": String(format: "%.0f%%", progress * 100)
        ])
    }

    func logAssetRequiresCloudDownload(assetId: String, networkAllowed: Bool) {
        log(.download, .info, "Asset requires iCloud download", details: [
            "assetId": truncateAssetId(assetId),
            "networkAllowed": networkAllowed
        ])
    }

    // MARK: - Performance Logging

    func logPerformance(operation: String, duration: TimeInterval, itemCount: Int? = nil) {
        var details: [String: Any] = [
            "operation": operation,
            "duration": String(format: "%.2fs", duration)
        ]
        if let count = itemCount, count > 0 {
            details["itemCount"] = count
            details["perItem"] = String(format: "%.0fms", (duration / Double(count)) * 1000)
        }
        log(.analysis, .performance, "Operation completed", details: details)
    }

    func logAnalysisCheckpoint(processed: Int, total: Int, localBytes: Int64, cloudOnlyCount: Int) {
        log(.analysis, .info, "Analysis checkpoint", details: [
            "processed": processed,
            "total": total,
            "localBytes": localBytes.formattedBytes(),
            "cloudOnlyCount": cloudOnlyCount
        ])
    }

    // MARK: - Security Logging

    func logNetworkAccessChanged(allowed: Bool, source: String) {
        log(.security, .security, "Network access setting changed", details: [
            "allowed": allowed,
            "source": source
        ])
    }

    func logBlockedNetworkRequest(assetId: String, reason: String) {
        log(.security, .warning, "Network request blocked", details: [
            "assetId": truncateAssetId(assetId),
            "reason": reason
        ])
    }

    func logUnexpectedNetworkAccess(context: String) {
        log(.security, .warning, "Unexpected network access attempt", details: [
            "context": context
        ])
    }

    // MARK: - Cache Logging

    func logCacheHit(assetId: String, quality: String) {
        log(.cache, .info, "Cache hit", details: [
            "assetId": truncateAssetId(assetId),
            "quality": quality
        ])
    }

    func logCacheMiss(assetId: String, quality: String, willDownload: Bool) {
        log(.cache, .info, "Cache miss", details: [
            "assetId": truncateAssetId(assetId),
            "quality": quality,
            "willDownload": willDownload
        ])
    }

    func logCacheCleared(reason: String) {
        log(.cache, .info, "Cache cleared", details: [
            "reason": reason
        ])
    }

    // MARK: - Network Logging

    func logNetworkStatusCheck(isReachable: Bool, connectionType: String) {
        log(.network, .info, "Network status checked", details: [
            "isReachable": isReachable,
            "connectionType": connectionType
        ])
    }

    // MARK: - Prefetch Logging

    func logPrefetchStarted(assetCount: Int, quality: String) {
        log(.cache, .info, "Prefetch started", details: [
            "assetCount": assetCount,
            "quality": quality
        ])
    }

    func logPrefetchStopped(assetCount: Int) {
        log(.cache, .info, "Prefetch stopped", details: [
            "assetCount": assetCount
        ])
    }

    // MARK: - Helpers

    /// Truncate asset ID to first 8 characters for privacy
    private func truncateAssetId(_ assetId: String) -> String {
        return String(assetId.prefix(8))
    }

}

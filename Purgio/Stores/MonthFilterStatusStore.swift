//
//  MonthFilterStatusStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Foundation
import Photos

final class MonthFilterStatusStore {
    static let shared = MonthFilterStatusStore()

    private let storageQueue = DispatchQueue(label: "MonthFilterStatusStore.storage")
    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let dir = base?.appendingPathComponent("Purgio", isDirectory: true)
        return (dir ?? URL(fileURLWithPath: NSTemporaryDirectory()))
            .appendingPathComponent("monthFilterStatus.json")
    }()
    private var cachedStatus: [String: MonthStatus] = [:]

    private init() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? JSONDecoder().decode([String: MonthStatus].self, from: data) {
            cachedStatus = decoded
        }
    }

    enum FilterType: String, CaseIterable {
        case allContent = "allContent"
        case screenshots = "screenshots"
        case largeFiles = "largeFiles"
        case eyesClosed = "eyesClosed"
        case similar = "similar"
        case screenRecordings = "screenRecordings"
        case slowMotion = "slowMotion"
        case timeLapse = "timeLapse"
    }

    private struct MonthStatus: Codable {
        var finishedFilters: [String]
    }

    func isFilterFinished(monthKey: String, filter: FilterType) -> Bool {
        assert(Thread.isMainThread)
        let status = cachedStatus[monthKey] ?? MonthStatus(finishedFilters: [])
        return status.finishedFilters.contains(filter.rawValue)
    }

    func markFilterFinished(monthKey: String, filter: FilterType) {
        assert(Thread.isMainThread)
        var status = cachedStatus[monthKey] ?? MonthStatus(finishedFilters: [])
        guard !status.finishedFilters.contains(filter.rawValue) else { return }
        status.finishedFilters.append(filter.rawValue)
        cachedStatus[monthKey] = status
        persistToDisk(cachedStatus)
    }

    func markFilterNotFinished(monthKey: String, filter: FilterType) {
        assert(Thread.isMainThread)
        var status = cachedStatus[monthKey] ?? MonthStatus(finishedFilters: [])
        let before = status.finishedFilters.count
        status.finishedFilters.removeAll { $0 == filter.rawValue }
        guard status.finishedFilters.count != before else { return }
        cachedStatus[monthKey] = status
        persistToDisk(cachedStatus)
    }

    func getFinishedFiltersCount(monthKey: String) -> Int {
        assert(Thread.isMainThread)
        let status = cachedStatus[monthKey] ?? MonthStatus(finishedFilters: [])
        return status.finishedFilters.count
    }

    func clearAllFinishedFilters(monthKey: String) {
        assert(Thread.isMainThread)
        guard cachedStatus.removeValue(forKey: monthKey) != nil else { return }
        persistToDisk(cachedStatus)
    }

    func areAllFiltersFinished(monthKey: String, mediaType: PHAssetMediaType = .image) -> Bool {
        assert(Thread.isMainThread)
        let filters = MonthFilterStatusStore.filters(for: mediaType)
        return getFinishedFiltersCount(monthKey: monthKey) == filters.count
    }

    static func filters(for mediaType: PHAssetMediaType) -> [FilterType] {
        if mediaType == .video {
            return [.allContent, .largeFiles, .screenRecordings, .slowMotion, .timeLapse]
        }
        return [.allContent, .screenshots, .largeFiles, .eyesClosed, .similar]
    }

    private func persistToDisk(_ status: [String: MonthStatus]) {
        let url = fileURL
        storageQueue.async {
            if let data = try? JSONEncoder().encode(status) {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }
}

//
//  DeleteBinStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.01.2026.
//

import Foundation

final class DeleteBinStore {
    static let shared = DeleteBinStore()

    private let storageQueue = DispatchQueue(label: "com.galary.DeleteBinStore.storage")
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Purgio/deleteBin.json")
    }()

    private var cachedIds: [String] = []
    private var cachedIdSet: Set<String> = []
    private var persistWorkItem: DispatchWorkItem?

    private init() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            cachedIds = ids
            cachedIdSet = Set(ids)
        }
    }

    private func persistToDisk(_ ids: [String]) {
        persistWorkItem?.cancel()
        let url = fileURL
        let item = DispatchWorkItem {
            if let data = try? JSONEncoder().encode(ids) {
                try? data.write(to: url, options: [.atomic])
            }
        }
        persistWorkItem = item
        storageQueue.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    var count: Int {
        assert(Thread.isMainThread)
        return cachedIds.count
    }

    func loadAssetIds() -> [String] {
        assert(Thread.isMainThread)
        return cachedIds
    }

    func saveAssetIds(_ ids: [String]) {
        assert(Thread.isMainThread)
        var seen = Set<String>()
        let unique = ids.filter { seen.insert($0).inserted }
        cachedIds = unique
        cachedIdSet = Set(unique)
        persistToDisk(unique)
        NotificationCenter.default.post(name: .deleteBinCountDidChange, object: nil)
    }

    func addAssetId(_ id: String) {
        assert(Thread.isMainThread)
        guard !cachedIdSet.contains(id) else { return }
        cachedIds.append(id)
        cachedIdSet.insert(id)
        persistToDisk(cachedIds)
        NotificationCenter.default.post(name: .deleteBinCountDidChange, object: nil)
    }

    func addAssetIds(_ ids: [String]) {
        assert(Thread.isMainThread)
        var changed = false
        for id in ids {
            guard !cachedIdSet.contains(id) else { continue }
            cachedIds.append(id)
            cachedIdSet.insert(id)
            changed = true
        }
        guard changed else { return }
        persistToDisk(cachedIds)
        NotificationCenter.default.post(name: .deleteBinCountDidChange, object: nil)
    }

    func hasAssetId(_ id: String) -> Bool {
        assert(Thread.isMainThread)
        return cachedIdSet.contains(id)
    }

    func removeAssetId(_ id: String) {
        assert(Thread.isMainThread)
        guard cachedIdSet.remove(id) != nil else { return }
        cachedIds.removeAll { $0 == id }
        persistToDisk(cachedIds)
        NotificationCenter.default.post(name: .deleteBinCountDidChange, object: nil)
    }

    func removeAssetIds(_ ids: [String]) {
        assert(Thread.isMainThread)
        let idsToRemove = Set(ids)
        let before = cachedIds.count
        cachedIds.removeAll { idsToRemove.contains($0) }
        cachedIdSet.subtract(idsToRemove)
        guard cachedIds.count != before else { return }
        persistToDisk(cachedIds)
        NotificationCenter.default.post(name: .deleteBinCountDidChange, object: nil)
    }

    func clearAll() {
        assert(Thread.isMainThread)
        cachedIds = []
        cachedIdSet = []
        persistToDisk([])
        NotificationCenter.default.post(name: .deleteBinCountDidChange, object: nil)
    }
}

extension Notification.Name {
    static let deleteBinCountDidChange = Notification.Name("deleteBinCountDidChange")
}

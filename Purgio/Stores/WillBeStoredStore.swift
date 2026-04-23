//
//  WillBeStoredStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Foundation

final class WillBeStoredStore {
    static let shared = WillBeStoredStore()

    private let storageQueue = DispatchQueue(label: "com.galary.WillBeStoredStore.storage")
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Purgio/willBeStored.json")
    }()

    private var cachedIds: [String] = []
    private var cachedIdSet: Set<String> = []

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
        let url = fileURL
        storageQueue.async {
            if let data = try? JSONEncoder().encode(ids) {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }

    var count: Int {
        assert(Thread.isMainThread)
        return cachedIds.count
    }

    func loadAssetIds() -> [String] {
        assert(Thread.isMainThread)
        return cachedIds
    }

    func hasAssetId(_ id: String) -> Bool {
        assert(Thread.isMainThread)
        return cachedIdSet.contains(id)
    }

    func addAssetId(_ id: String) {
        assert(Thread.isMainThread)
        guard !cachedIdSet.contains(id) else { return }
        cachedIds.append(id)
        cachedIdSet.insert(id)
        persistToDisk(cachedIds)
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
    }

    func removeAssetId(_ id: String) {
        assert(Thread.isMainThread)
        guard cachedIdSet.remove(id) != nil else { return }
        cachedIds.removeAll { $0 == id }
        persistToDisk(cachedIds)
    }

    func removeAssetIds(_ ids: [String]) {
        assert(Thread.isMainThread)
        let idsToRemove = Set(ids)
        let before = cachedIds.count
        cachedIds.removeAll { idsToRemove.contains($0) }
        cachedIdSet.subtract(idsToRemove)
        guard cachedIds.count != before else { return }
        persistToDisk(cachedIds)
    }

    func clearAll() {
        assert(Thread.isMainThread)
        cachedIds = []
        cachedIdSet = []
        persistToDisk([])
    }
}

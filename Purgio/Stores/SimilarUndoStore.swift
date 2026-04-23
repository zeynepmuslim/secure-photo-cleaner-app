//
//  SimilarUndoStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.01.2026.
//

import Foundation
import Photos

struct PersistedUndoAction: Codable {
    let groupSignature: String
    let deletedIds: [String]
    let keptIds: [String]
    let storedIds: [String]
    let timestamp: Date
}

final class SimilarUndoStore {
    static let shared = SimilarUndoStore()

    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Purgio/similarUndo.json")
    }()

    private var cachedActions: [PersistedUndoAction] = []
    private var persistTask: Task<Void, Never>?

    private init() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        if let fileData = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([PersistedUndoAction].self, from: fileData)
        {
            cachedActions = decoded
        }

        pruneOldActions()
    }

    private func persistToDisk() {
        persistTask?.cancel()
        let snapshot = cachedActions
        let url = fileURL
        persistTask = Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }

    func saveAction(_ action: PersistedUndoAction) {
        assert(Thread.isMainThread, "SimilarUndoStore must be accessed from main thread")
        cachedActions.removeAll { $0.groupSignature == action.groupSignature }
        cachedActions.append(action)
        persistToDisk()
    }

    func removeAction(forGroupSignature signature: String) {
        assert(Thread.isMainThread, "SimilarUndoStore must be accessed from main thread")
        cachedActions.removeAll { $0.groupSignature == signature }
        persistToDisk()
    }

    func getAction(forGroupSignature signature: String) -> PersistedUndoAction? {
        assert(Thread.isMainThread, "SimilarUndoStore must be accessed from main thread")
        return cachedActions.first { $0.groupSignature == signature }
    }

    func getAllInvolvedAssetIds() -> Set<String> {
        assert(Thread.isMainThread, "SimilarUndoStore must be accessed from main thread")
        var ids = Set<String>()
        for action in cachedActions {
            ids.formUnion(action.deletedIds)
            ids.formUnion(action.keptIds)
            ids.formUnion(action.storedIds)
        }
        return ids
    }

    private func pruneOldActions(olderThan days: Int = 30) {
        guard let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        let countBefore = cachedActions.count
        cachedActions.removeAll { $0.timestamp < cutoff }
        if cachedActions.count < countBefore {
            persistToDisk()
        }
    }
}

//
//  UndoHistoryManager.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Foundation
import Photos
import UIKit
import os

private let logger = Logger(subsystem: "com.purgio", category: "UndoHistory")

final class UndoHistoryManager {
    static let shared = UndoHistoryManager()

    private let queue = DispatchQueue(label: "com.purgio.undohistory", attributes: .concurrent)

    private var sessionActions: [String: [UndoAction]] = [:]

    private var _currentSessionKey: SessionKey?
    private var currentSessionKey: SessionKey? {
        get { queue.sync { _currentSessionKey } }
        set { queue.async(flags: .barrier) { self._currentSessionKey = newValue } }
    }

    private var _currentSessionId: UUID
    private(set) var currentSessionId: UUID {
        get { queue.sync { _currentSessionId } }
        set { queue.async(flags: .barrier) { self._currentSessionId = newValue } }
    }

    private let fileManager = FileManager.default
    private let historyFileName = "undoHistory.json"
    private var saveWorkItem: DispatchWorkItem?

    private var historyFileURL: URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(historyFileName)
    }

    var canUndo: Bool {
        guard let key = currentSessionKey else { return false }
        return queue.sync { !(_sessionActions(for: key).isEmpty) }
    }

    var undoCount: Int {
        guard let key = currentSessionKey else { return 0 }
        return queue.sync { _sessionActions(for: key).count }
    }

    private init() {
        _currentSessionId = UUID()
        loadFromDisk()
    }

    func startSession(with key: SessionKey) {
        queue.async(flags: .barrier) {
            self._currentSessionKey = key

            let keyString = key.undoKeyString
            if self.sessionActions[keyString] == nil {
                self.sessionActions[keyString] = []
                self._currentSessionId = UUID()
            }
        }

        notifyChanges()
    }

    func recordAction(
        _ type: UndoAction.ActionType, for assetLocalIdentifier: String, at index: Int, assetSize: Int64 = 0
    ) {
        guard let key = currentSessionKey else { return }

        queue.async(flags: .barrier) {
            let keyString = key.undoKeyString
            var actions = self.sessionActions[keyString] ?? []

            let newAction = UndoAction(
                id: UUID(),
                actionType: type,
                assetLocalIdentifier: assetLocalIdentifier,
                index: index,
                assetSize: assetSize,
                timestamp: Date(),
                sessionId: self._currentSessionId
            )

            actions.append(newAction)
            self.sessionActions[keyString] = actions

            self.scheduleSave()
        }

        notifyChanges()
    }

    @discardableResult
    func undoLastAction() -> UndoAction? {
        guard let key = currentSessionKey else { return nil }

        var action: UndoAction?
        queue.sync(flags: .barrier) {
            let keyString = key.undoKeyString
            guard var actions = self.sessionActions[keyString], !actions.isEmpty else { return }

            action = actions.removeLast()
            self.sessionActions[keyString] = actions
            self.scheduleSave()
        }

        notifyChanges()
        return action
    }

    func getCurrentSessionActions() -> [UndoAction] {
        guard let key = currentSessionKey else { return [] }
        return queue.sync { _sessionActions(for: key) }
    }

    /// Internal helper to get actions
    private func _sessionActions(for key: SessionKey) -> [UndoAction] {
        return sessionActions[key.undoKeyString] ?? []
    }

    /// Update a specific action's type at the given index (reversed index)
    func updateAction(at reversedIndex: Int, newActionType: UndoAction.ActionType) -> UndoAction? {
        guard let key = currentSessionKey else { return nil }
        var updatedAction: UndoAction?

        queue.sync(flags: .barrier) {
            let keyString = key.undoKeyString
            guard var actions = self.sessionActions[keyString], !actions.isEmpty else { return }

            let actualIndex = actions.count - 1 - reversedIndex

            guard actualIndex >= 0 && actualIndex < actions.count else { return }

            let oldAction = actions[actualIndex]

            updatedAction = UndoAction(
                id: oldAction.id,
                actionType: newActionType,
                assetLocalIdentifier: oldAction.assetLocalIdentifier,
                index: oldAction.index,
                assetSize: oldAction.assetSize,
                timestamp: Date(),
                sessionId: oldAction.sessionId
            )

            if let newAction = updatedAction {
                actions[actualIndex] = newAction
                self.sessionActions[keyString] = actions
                self.scheduleSave()
            }
        }

        notifyChanges()
        return updatedAction
    }

    /// Remove specific actions by their IDs (for selective undo)
    func removeActions(withIDs ids: Set<UUID>) -> [UndoAction] {
        guard let key = currentSessionKey else { return [] }

        var removedActions: [UndoAction] = []

        queue.sync(flags: .barrier) {
            let keyString = key.undoKeyString
            guard let actions = self.sessionActions[keyString] else { return }

            var newActions: [UndoAction] = []

            for action in actions {
                if ids.contains(action.id) {
                    removedActions.append(action)
                } else {
                    newActions.append(action)
                }
            }

            self.sessionActions[keyString] = newActions
            self.scheduleSave()
        }

        notifyChanges()
        return removedActions
    }

    func popAll() -> [UndoAction] {
        guard let key = currentSessionKey else { return [] }

        var allActions: [UndoAction] = []
        queue.sync(flags: .barrier) {
            let keyString = key.undoKeyString
            allActions = self.sessionActions[keyString] ?? []
            self.sessionActions[keyString] = []
            self.scheduleSave()
        }

        notifyChanges()
        return allActions
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.performSave()
        }
        saveWorkItem = workItem
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }

    private func performSave() {
        guard let fileURL = historyFileURL else { return }

        let snapshot = queue.sync { self.sessionActions }

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL)
        } catch {
            logger.error("Failed to save history to disk: \(error.localizedDescription)")
        }
    }

    private func loadFromDisk() {
        guard let fileURL = historyFileURL,
            fileManager.fileExists(atPath: fileURL.path)
        else {
            #if DEBUG
                logger.debug("No history file found")
            #endif
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([String: [UndoAction]].self, from: data)

            queue.async(flags: .barrier) {
                self.sessionActions = loaded
            }

            #if DEBUG
                logger.debug("Loaded \(loaded.count) sessions from disk")
            #endif

            cleanupOldSessions()
        } catch {
            logger.error("Failed to load history from disk: \(error.localizedDescription)")
        }
    }

    // MARK: - Cleanup

    private func cleanupOldSessions(maxSessions: Int = 50) {
        queue.async(flags: .barrier) {
            guard self.sessionActions.count > maxSessions else { return }

            let sorted = self.sessionActions
                .compactMap { key, actions -> (String, Date)? in
                    guard let latest = actions.map(\.timestamp).max() else { return nil }
                    return (key, latest)
                }
                .sorted { $0.1 < $1.1 }

            let removeCount = self.sessionActions.count - maxSessions
            for (key, _) in sorted.prefix(removeCount) {
                self.sessionActions.removeValue(forKey: key)
            }
            self.scheduleSave()
        }
    }

    /// Get statistics about actions in the current session
    func getStatistics() -> (deleted: Int, kept: Int, stored: Int) {
        guard let key = currentSessionKey else { return (0, 0, 0) }
        let actions = queue.sync { _sessionActions(for: key) }

        var deleted = 0
        var kept = 0
        var stored = 0

        for action in actions {
            switch action.actionType {
            case .delete:
                deleted += 1
            case .keep:
                kept += 1
            case .store:
                stored += 1
            }
        }

        return (deleted, kept, stored)
    }

    func removeActionsForDeletedAssets() {
        guard let key = currentSessionKey else { return }

        let (keyString, actions) = queue.sync { () -> (String, [UndoAction]) in
            let ks = key.undoKeyString
            return (ks, self.sessionActions[ks] ?? [])
        }
        guard !actions.isEmpty else { return }

        let identifiers = actions.map { $0.assetLocalIdentifier }
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var existingIds = Set<String>()
        fetchResult.enumerateObjects { asset, _, _ in
            existingIds.insert(asset.localIdentifier)
        }

        queue.async(flags: .barrier) {
            guard let current = self.sessionActions[keyString] else { return }
            let filtered = current.filter { existingIds.contains($0.assetLocalIdentifier) }
            if filtered.count != current.count {
                self.sessionActions[keyString] = filtered
                self.scheduleSave()
                self.notifyChanges()
            }
        }
    }

    private func notifyChanges() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .undoHistoryDidChange, object: nil)
        }
    }
}

// MARK: - Notification
extension Notification.Name {
    static let undoHistoryDidChange = Notification.Name("undoHistoryDidChange")
}

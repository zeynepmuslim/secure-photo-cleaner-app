//
//  BinDecision.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.11.2026.
//

import Foundation
import Photos

/// Takes an item out of the Delete Bin as a review decision (Keep or Store) made from the bin's
/// preview: it leaves the bin, joins the kept or stored store (and album), the swipe's stats are
/// reversed, the month's progress moves one item from deleted to the new choice, and the undo
/// history's action for it changes type. Main thread only: the stores assert it.
enum BinDecision {

    static func apply(_ type: UndoAction.ActionType, to asset: PHAsset) {
        assert(Thread.isMainThread)
        guard type != .delete else { return }
        let id = asset.localIdentifier

        DeleteBinStore.shared.removeAssetId(id)
        switch type {
        case .keep:
            KeptAssetsStore.shared.addAssetId(id)
        case .store:
            WillBeStoredStore.shared.addAssetId(id)
            Task {
                _ = await PhotoLibraryService.shared.addAssetToWillBeStoredAlbum(asset: asset)
            }
        case .delete:
            break
        }

        // The swipe counted it as deleted; `StatsStore` is safe from any thread.
        let mediaType = asset.mediaType
        DispatchQueue.global(qos: .userInitiated).async {
            StatsStore.shared.undoDeletion(for: mediaType, bytes: asset.resourceMetadata().fileSize)
        }

        let date = asset.creationDate ?? Date()
        let monthKey = DateFormatterManager.shared.monthKey(from: date)
        let year = Calendar.current.component(.year, from: date)
        let yearKey = "year-\(year)"
        // A sparse year is reviewed as one session, so its record is the year's, not the month's.
        if !moveProgress(key: monthKey, mediaType: mediaType, to: type) {
            moveProgress(key: yearKey, mediaType: mediaType, to: type)
        }

        let mediaTypeKey = String(mediaType.rawValue)
        UndoHistoryManager.shared.changeActionType(
            assetLocalIdentifier: id,
            in: [
                SessionKey(monthKey: monthKey, mediaType: mediaTypeKey),
                SessionKey(monthKey: yearKey, mediaType: mediaTypeKey)
            ],
            to: type)
    }

    /// One item moves from deleted to kept or stored in a month's or year's main record; reviewed
    /// and the total stay. Returns false, changing nothing, when there's no record for the key.
    @discardableResult
    private static func moveProgress(key: String, mediaType: PHAssetMediaType, to type: UndoAction.ActionType) -> Bool {
        let store = ReviewProgressStore.shared
        let recordKey = (mediaType == .video ? "video_" : "photo_") + key
        guard store.getAllProgress()[recordKey] != nil else { return false }
        let progress = store.getProgress(forMonthKey: key, mediaType: mediaType)
        store.saveProgress(
            forMonthKey: key,
            mediaType: mediaType,
            currentIndex: progress.currentIndex,
            reviewedCount: progress.reviewedCount,
            deletedCount: max(0, progress.deletedCount - 1),
            keptCount: progress.keptCount + (type == .keep ? 1 : 0),
            storedCount: progress.storedCount + (type == .store ? 1 : 0),
            originalTotalCount: progress.originalTotalCount)
        return true
    }
}

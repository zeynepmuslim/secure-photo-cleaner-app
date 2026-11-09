//
//  MonthReviewViewController+UndoHistory.swift
//  Purgio
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import Photos
import UIKit

extension MonthReviewViewController {

    @objc func showUndoHistory() {
        let historyVC = UndoHistoryViewController()
        historyVC.delegate = self
        let navController = UINavigationController(rootViewController: historyVC)

        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }

        present(navController, animated: true)
    }
}

// MARK: - Undo Helpers

extension MonthReviewViewController {

    /// Where an undo action's asset sits in this deck, found by its identifier.
    ///
    /// `action.index` points into the asset array of the session that recorded it. That array can
    /// differ from this one: filter sessions of a month share one undo stack, the stack survives
    /// relaunches, and the library can gain or lose assets in between. Indexing with it could touch
    /// the wrong asset or crash, so it is never used. Nil when this deck doesn't hold the asset.
    func deckIndex(of action: UndoAction) -> Int? {
        reviewAssets.firstIndex { $0.localIdentifier == action.assetLocalIdentifier }
    }

    /// Adds the action's asset to, or removes it from, the "Will Be Stored" album. Uses the deck's
    /// asset when it holds it, otherwise fetches it by identifier.
    func updateWillBeStoredAlbum(for action: UndoAction, adding: Bool) {
        let deckAsset = deckIndex(of: action).map { reviewAssets[$0].asset }
        let identifier = action.assetLocalIdentifier
        let service = photoLibraryService
        Task {
            let asset: PHAsset?
            if let deckAsset {
                asset = deckAsset
            } else {
                asset = await service.fetchAssets(withLocalIdentifiers: [identifier]).first
            }
            guard let asset else { return }
            if adding {
                _ = await service.addAssetToWillBeStoredAlbum(asset: asset)
            } else {
                _ = await service.removeAssetFromWillBeStoredAlbum(asset: asset)
            }
        }
    }

    /// Takes the actions' assets out of the stores and album and reverts their stats. The deck's
    /// counts are recalculated from the stores afterwards, so an asset outside this deck can't skew them.
    func revertUndoActions(_ actions: [UndoAction]) {
        let ids = actions.map(\.assetLocalIdentifier)
        deleteBinStore.removeAssetIds(ids)
        KeptAssetsStore.shared.removeAssetIds(ids)
        willBeStoredStore.removeAssetIds(ids)

        for action in actions {
            switch action.actionType {
            case .delete:
                statsStore.undoDeletion(for: mediaType, bytes: action.assetSize)
                sessionIncrementCount = max(0, sessionIncrementCount - 1)
            case .keep:
                break
            case .store:
                updateWillBeStoredAlbum(for: action, adding: false)
            }
            statsStore.undoReview(for: mediaType)
        }

        // Back to the earliest undone asset this deck holds; if it holds none, the deck stays put
        if let earliest = actions.compactMap({ deckIndex(of: $0) }).min() {
            currentIndex = earliest
        }
        recalculateCountsFromStores()
    }
}

// MARK: - UndoHistoryDelegate

extension MonthReviewViewController: UndoHistoryDelegate {
    func didPerformAction(_ actionType: UndoAction.ActionType, on action: UndoAction) {
        let identifier = action.assetLocalIdentifier

        deleteBinStore.removeAssetId(identifier)
        KeptAssetsStore.shared.removeAssetId(identifier)
        willBeStoredStore.removeAssetId(identifier)

        switch action.actionType {
        case .delete:
            statsStore.undoDeletion(for: mediaType, bytes: action.assetSize)
            sessionIncrementCount = max(0, sessionIncrementCount - 1)
        case .keep:
            break
        case .store:
            updateWillBeStoredAlbum(for: action, adding: false)
        }

        // new action
        switch actionType {
        case .delete:
            deleteBinStore.addAssetId(identifier)
            statsStore.recordDeletion(for: mediaType, bytes: action.assetSize)
            sessionIncrementCount += 1
        case .keep:
            KeptAssetsStore.shared.addAssetId(identifier)
        case .store:
            willBeStoredStore.addAssetId(identifier)
            updateWillBeStoredAlbum(for: action, adding: true)
        }

        recalculateCountsFromStores()
        updateGlobalBinButtonIncrement()
        saveProgress()
        refreshStack()
        haptics.success()
    }

    func didUndoAll(_ actions: [UndoAction]) {
        revertUndoActions(actions)
        updateGlobalBinButtonIncrement()
        saveProgress()
        refreshStack()
        haptics.success()
    }

    func didUndoActions(_ actions: [UndoAction]) {
        revertUndoActions(actions)
        updateGlobalBinButtonIncrement()
        saveProgress()
        refreshStack()
        haptics.success()
    }
}

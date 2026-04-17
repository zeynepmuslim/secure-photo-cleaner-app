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

extension MonthReviewViewController: UndoHistoryDelegate {
    func didPerformAction(_ actionType: UndoAction.ActionType, on action: UndoAction) {
        let asset = reviewAssets[action.index].asset

        deleteBinStore.removeAssetId(asset.localIdentifier)
        KeptAssetsStore.shared.removeAssetId(asset.localIdentifier)
        willBeStoredStore.removeAssetId(asset.localIdentifier)

        switch action.actionType {
        case .delete:
            deletedCount -= 1
            statsStore.undoDeletion(for: mediaType, bytes: action.assetSize)
            sessionIncrementCount = max(0, sessionIncrementCount - 1)
        case .keep:
            keptCount -= 1
        case .store:
            storedCount -= 1
            Task {
                _ = await photoLibraryService.removeAssetFromWillBeStoredAlbum(asset: asset)
            }
        }

        // new action
        switch actionType {
        case .delete:
            deleteBinStore.addAssetId(asset.localIdentifier)
            deletedCount += 1
            statsStore.recordDeletion(for: mediaType, bytes: action.assetSize)
            sessionIncrementCount += 1

        case .keep:
            KeptAssetsStore.shared.addAssetId(asset.localIdentifier)
            keptCount += 1

        case .store:
            willBeStoredStore.addAssetId(asset.localIdentifier)
            storedCount += 1

            Task {
                _ = await photoLibraryService.addAssetToWillBeStoredAlbum(asset: asset)
            }
        }

        updateGlobalBinButtonIncrement()
        saveProgress()
        refreshStack()
        haptics.success()
    }

    func didUndoAll(_ actions: [UndoAction]) {
        let allIds = actions.map { reviewAssets[$0.index].asset.localIdentifier }
        deleteBinStore.removeAssetIds(allIds)

        KeptAssetsStore.shared.removeAssetIds(allIds)
        willBeStoredStore.removeAssetIds(allIds)

        for action in actions.reversed() {
            let asset = reviewAssets[action.index].asset

            switch action.actionType {
            case .delete:
                deletedCount -= 1
                statsStore.undoDeletion(for: mediaType, bytes: action.assetSize)
                sessionIncrementCount = max(0, sessionIncrementCount - 1)
            case .keep:
                keptCount -= 1
            case .store:
                storedCount -= 1
                Task {
                    _ = await photoLibraryService.removeAssetFromWillBeStoredAlbum(asset: asset)
                }
            }
            statsStore.undoReview(for: mediaType)
        }

        if let firstAction = actions.first {
            currentIndex = firstAction.index
        }

        updateGlobalBinButtonIncrement()
        saveProgress()
        refreshStack()
        haptics.success()
    }

    func didUndoActions(_ actions: [UndoAction]) {
        let allIds = actions.map { reviewAssets[$0.index].asset.localIdentifier }
        deleteBinStore.removeAssetIds(allIds)

        var earliestIndex = Int.max

        KeptAssetsStore.shared.removeAssetIds(allIds)
        willBeStoredStore.removeAssetIds(allIds)

        for action in actions {
            let asset = reviewAssets[action.index].asset

            switch action.actionType {
            case .delete:
                deletedCount -= 1
                statsStore.undoDeletion(for: mediaType, bytes: action.assetSize)
                sessionIncrementCount = max(0, sessionIncrementCount - 1)
            case .keep:
                keptCount -= 1
            case .store:
                storedCount -= 1
                Task {
                    _ = await photoLibraryService.removeAssetFromWillBeStoredAlbum(asset: asset)
                }
            }
            statsStore.undoReview(for: mediaType)

            if action.index < earliestIndex {
                earliestIndex = action.index
            }
        }

        // Reset current index to the earliest undone action's index
        if earliestIndex != Int.max {
            currentIndex = earliestIndex
        }

        updateGlobalBinButtonIncrement()
        saveProgress()
        refreshStack()
        haptics.success()
    }
}

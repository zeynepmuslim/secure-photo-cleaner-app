//
//  SimilarPhotosViewController+Actions.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let cancel = CommonStrings.cancel
    static let batchConfirmTitle = NSLocalizedString("similarPhotos.batchConfirmTitle", comment: "Confirm all groups title")
    static let batchConfirmAction = NSLocalizedString("similarPhotos.batchConfirmAction", comment: "Add to bin button")
    static func batchConfirmMessage(keepCount: Int, deleteCount: Int, storeCount: Int, groupCount: Int) -> String {
        var parts: [String] = []
        if keepCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.keepCount", comment: "Keep photo count"), keepCount))
        }
        if deleteCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.deleteCount", comment: "Delete photo count"), deleteCount))
        }
        if storeCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.storeCount", comment: "Store photo count"), storeCount))
        }
        let fromGroups = String.localizedStringWithFormat(NSLocalizedString("similarPhotos.fromGroups", comment: "From group count, e.g. 'From 3 groups'"), groupCount)
        return parts.joined(separator: "\n") + "\n\n" + fromGroups
    }
}

// MARK: - Confirm and undo

extension SimilarPhotosViewController {

    /// A set's photos by their marks.
    private func assetsByState(inSetAt index: Int) -> (keep: [PHAsset], delete: [PHAsset], store: [PHAsset]) {
        let states = setStates[index] ?? [:]
        var keep: [PHAsset] = []
        var delete: [PHAsset] = []
        var store: [PHAsset] = []
        for asset in similarGroups[index].assets {
            switch states[asset.localIdentifier] ?? .delete {
            case .keep: keep.append(asset)
            case .delete: delete.append(asset)
            case .store: store.append(asset)
            }
        }
        return (keep, delete, store)
    }

    // MARK: Confirm

    func confirmSet(at index: Int) {
        guard index < similarGroups.count, !processedGroupIndexes.contains(index) else { return }

        processGroup(at: index)
        HapticFeedbackManager.shared.success()
        showConfirmedChange(forSetsAt: [index])

        if unconfirmedIndices.isEmpty {
            // Let the card collapse first
            DispatchQueue.main.asyncAfter(deadline: .now() + Layout.springDuration) { [weak self] in
                guard let self, self.unconfirmedIndices.isEmpty, !self.isShowingEmptyState else { return }
                self.showAllCheckedState()
            }
        }
    }

    /// Moves a set's photos to the bin, kept and stored stores, records the stats and the
    /// progress, and keeps what was done for Undo (here and after a rescan).
    private func processGroup(at index: Int) {
        let group = similarGroups[index]
        let signature = signatures[index]
        let (keeping, deleting, storing) = assetsByState(inSetAt: index)

        DeleteBinStore.shared.addAssetIds(deleting.map(\.localIdentifier))

        for asset in deleting {
            StatsStore.shared.recordDeletion(for: asset.mediaType, bytes: byteSize(of: asset, inSetAt: index))
        }

        // Keep + delete + store = every photo of the set is reviewed
        for asset in keeping + deleting + storing {
            StatsStore.shared.recordReview(for: asset.mediaType)
        }

        KeptAssetsStore.shared.addAssetIds(keeping.map(\.localIdentifier))

        WillBeStoredStore.shared.addAssetIds(storing.map(\.localIdentifier))
        for asset in storing {
            Task {
                _ = await photoLibraryService.addAssetToWillBeStoredAlbum(asset: asset)
            }
        }

        processedGroupIndexes.insert(index)
        confirmedThisVisit.insert(index)

        updateProgress(
            deletedCount: deleting.count,
            keptCount: keeping.count,
            storedCount: storing.count,
            totalProcessedCount: group.assets.count
        )

        processedActions[index] = UndoAction(
            groupIndex: index,
            deletedAssets: deleting,
            keptAssets: keeping,
            storedAssets: storing
        )

        SimilarUndoStore.shared.saveAction(
            PersistedUndoAction(
                groupSignature: signature,
                deletedIds: deleting.map { $0.localIdentifier },
                keptIds: keeping.map { $0.localIdentifier },
                storedIds: storing.map { $0.localIdentifier },
                timestamp: Date()
            ))
    }

    // MARK: Confirm all

    @objc func confirmAllTapped() {
        let unconfirmed = unconfirmedIndices
        guard !unconfirmed.isEmpty else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)

        var totalKeep = 0
        var totalDelete = 0
        var totalStore = 0
        for index in unconfirmed {
            for state in (setStates[index] ?? [:]).values {
                switch state {
                case .keep: totalKeep += 1
                case .delete: totalDelete += 1
                case .store: totalStore += 1
                }
            }
        }

        let alert = UIAlertController(
            title: Strings.batchConfirmTitle,
            message: Strings.batchConfirmMessage(
                keepCount: totalKeep, deleteCount: totalDelete,
                storeCount: totalStore, groupCount: unconfirmed.count),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: Strings.cancel, style: .cancel) { _ in
                HapticFeedbackManager.shared.impact(intensity: .light)
            })
        alert.addAction(
            UIAlertAction(title: Strings.batchConfirmAction, style: .destructive) { [weak self] _ in
                self?.confirmAll()
            })
        present(alert, animated: true)
    }

    private func confirmAll() {
        let unconfirmed = unconfirmedIndices
        guard !unconfirmed.isEmpty else { return }
        exitStoreModeOnAllCards(except: nil)
        unconfirmed.forEach { processGroup(at: $0) }
        HapticFeedbackManager.shared.success()
        showAllCheckedState()
    }

    // MARK: Undo

    func undoSet(at index: Int) {
        guard processedActions[index] != nil else { return }
        revert(setsAt: [index])
        HapticFeedbackManager.shared.impact(intensity: .medium)
        showConfirmedChange(forSetsAt: [index])
    }

    /// Takes confirmed sets back: their photos leave the bin, kept and stored stores (and the
    /// album), and the stats, the progress and the persisted undo records are reverted.
    func revert(setsAt indices: [Int]) {
        var deletedIds: [String] = []
        var keptIds: [String] = []
        var storedAssets: [PHAsset] = []

        for index in indices {
            guard let action = processedActions[index] else { continue }

            deletedIds.append(contentsOf: action.deletedAssets.map(\.localIdentifier))
            keptIds.append(contentsOf: action.keptAssets.map(\.localIdentifier))
            storedAssets.append(contentsOf: action.storedAssets)

            for asset in action.deletedAssets {
                StatsStore.shared.undoDeletion(for: asset.mediaType, bytes: byteSize(of: asset, inSetAt: index))
            }
            for asset in action.deletedAssets + action.keptAssets + action.storedAssets {
                StatsStore.shared.undoReview(for: asset.mediaType)
            }

            revertProgress(
                deletedCount: action.deletedAssets.count,
                keptCount: action.keptAssets.count,
                storedCount: action.storedAssets.count,
                totalProcessedCount: action.deletedAssets.count + action.keptAssets.count + action.storedAssets.count
            )

            SimilarUndoStore.shared.removeAction(forGroupSignature: signatures[index])
            processedGroupIndexes.remove(index)
            processedActions.removeValue(forKey: index)
            confirmedThisVisit.remove(index)
        }

        DeleteBinStore.shared.removeAssetIds(deletedIds)
        KeptAssetsStore.shared.removeAssetIds(keptIds)
        WillBeStoredStore.shared.removeAssetIds(storedAssets.map(\.localIdentifier))
        for asset in storedAssets {
            Task { _ = await photoLibraryService.removeAssetFromWillBeStoredAlbum(asset: asset) }
        }
    }

    // MARK: Showing the change

    /// A set was confirmed or taken back: its card collapses into the confirmed row or expands
    /// again with the spring, the spotlight moves on, and the summary follows.
    private func showConfirmedChange(forSetsAt indices: [Int]) {
        let previousSpotlight = spotlightIndex
        let items: [Item] = indices.compactMap { index in
            // The spotlight's set is replaced in a cross-dissolve instead
            guard !(splitLayout == .upright && index == previousSpotlight) else { return nil }
            return .set(signatures[index])
        }

        if !items.isEmpty, let dataSource {
            UIView.animate(
                withDuration: Layout.springDuration, delay: 0,
                usingSpringWithDamping: Layout.springDamping, initialSpringVelocity: Layout.springVelocity,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                for index in indices {
                    guard !(self.splitLayout == .upright && index == previousSpotlight) else { continue }
                    self.visibleCard(forSetAt: index)?.setConfirmed(self.processedGroupIndexes.contains(index))
                }
                // Re-measures the cells: the list follows the cards' new heights
                var snapshot = dataSource.snapshot()
                let present = items.filter { snapshot.indexOfItem($0) != nil }
                snapshot.reconfigureItems(present)
                dataSource.apply(snapshot, animatingDifferences: true)
                self.collectionView.layoutIfNeeded()
            }
        }

        updateSpotlight(animated: true)
        refreshSummary()
    }

    // MARK: Progress

    private func updateProgress(deletedCount: Int, keptCount: Int, storedCount: Int, totalProcessedCount: Int) {
        guard let monthKey = monthKey else { return }

        let similarKey = "\(monthKey)_similar"
        let currentSimilar = ReviewProgressStore.shared.getProgress(forMonthKey: similarKey, mediaType: mediaType)
        let currentMain = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)

        // Batch: single persist for both keys
        ReviewProgressStore.shared.batchSave([
            (monthKey: similarKey, mediaType: mediaType,
             currentIndex: currentSimilar.currentIndex + totalProcessedCount,
             reviewedCount: currentSimilar.reviewedCount + totalProcessedCount,
             deletedCount: currentSimilar.deletedCount + deletedCount,
             keptCount: currentSimilar.keptCount + keptCount,
             storedCount: currentSimilar.storedCount + storedCount,
             originalTotalCount: currentSimilar.originalTotalCount),
            (monthKey: monthKey, mediaType: mediaType,
             currentIndex: currentMain.currentIndex,
             reviewedCount: currentMain.reviewedCount + totalProcessedCount,
             deletedCount: currentMain.deletedCount + deletedCount,
             keptCount: currentMain.keptCount + keptCount,
             storedCount: currentMain.storedCount + storedCount,
             originalTotalCount: currentMain.originalTotalCount)
        ])

        let newReviewedCount = currentMain.reviewedCount + totalProcessedCount
        ReminderDataCenter.shared.markSimilarReviewActivity(
            monthKey: monthKey,
            mediaType: mediaType,
            reviewedCount: newReviewedCount,
            totalCount: currentMain.originalTotalCount
        )
    }

    private func revertProgress(deletedCount: Int, keptCount: Int, storedCount: Int, totalProcessedCount: Int) {
        guard let monthKey = monthKey else { return }

        let similarKey = "\(monthKey)_similar"
        let currentSimilar = ReviewProgressStore.shared.getProgress(forMonthKey: similarKey, mediaType: mediaType)
        let currentMain = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)

        // Batch: single persist for both keys
        ReviewProgressStore.shared.batchSave([
            (monthKey: similarKey, mediaType: mediaType,
             currentIndex: max(0, currentSimilar.currentIndex - totalProcessedCount),
             reviewedCount: max(0, currentSimilar.reviewedCount - totalProcessedCount),
             deletedCount: max(0, currentSimilar.deletedCount - deletedCount),
             keptCount: max(0, currentSimilar.keptCount - keptCount),
             storedCount: max(0, currentSimilar.storedCount - storedCount),
             originalTotalCount: currentSimilar.originalTotalCount),
            (monthKey: monthKey, mediaType: mediaType,
             currentIndex: currentMain.currentIndex,
             reviewedCount: max(0, currentMain.reviewedCount - totalProcessedCount),
             deletedCount: max(0, currentMain.deletedCount - deletedCount),
             keptCount: max(0, currentMain.keptCount - keptCount),
             storedCount: max(0, currentMain.storedCount - storedCount),
             originalTotalCount: currentMain.originalTotalCount)
        ])
    }
}

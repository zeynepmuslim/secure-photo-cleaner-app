//
//  MonthReviewViewController+DataLoading.swift
//  Purgio
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import Photos
import UIKit

extension MonthReviewViewController {

    func loadPhotos() {
        let currentMonthKey = monthKey
        let currentProgressKey = makeProgressKey()
        let currentMediaType = mediaType
        let currentFilterContext = filterContext
        let preSorted = preSortedAssets
        let preComputed = preComputedAssets
        let service = photoLibraryService

        loadingTask = Task {
            let reviewAssets: [ReviewAsset]
            let skipICloud = SettingsStore.shared.skipICloudPhotos && !SettingsStore.shared.allowInternetAccess
            let savedProgress = ReviewProgressStore.shared.getProgress(
                forMonthKey: currentProgressKey, mediaType: currentMediaType)

            if let preComputed = preComputed {
                reviewAssets = preComputed
            } else {
                var assets: [PHAsset]
                let sourceAssets: [PHAsset]
                if let preSorted = preSorted {
                    sourceAssets = preSorted
                } else {
                    sourceAssets = await service.fetchPhotos(
                        forMonthKey: currentMonthKey, mediaType: currentMediaType)
                }

                switch currentFilterContext {
                case .none:
                    assets = sourceAssets
                case .screenshots:
                    assets = sourceAssets.filter { $0.mediaSubtypes.contains(.photoScreenshot) }
                case .screenRecordings:
                    assets = sourceAssets.filter { $0.mediaSubtypes.contains(.videoScreenRecording) }
                case .slowMotion:
                    assets = sourceAssets.filter { $0.mediaSubtypes.contains(.videoHighFrameRate) }
                case .timeLapse:
                    assets = sourceAssets.filter { $0.mediaSubtypes.contains(.videoTimelapse) }
                case .largeFiles, .eyesClosed:
                    assets = sourceAssets
                }

                if Task.isCancelled { return }

                var processedAssets: [ReviewAsset] = []
                var shownInitialBatch = false
                let stream = await PhotoProcessor.shared.processAssets(assets)

                for await result in stream {
                    switch result {
                    case .progress:
                        break
                    case .initialBatchReady(let partial):
                        guard !Task.isCancelled else { return }

                        let didShow = await MainActor.run { [weak self] () -> Bool in
                            guard let self, self.reviewAssets.isEmpty else { return false }
                            // Start at the first unprocessed asset, not the saved index (see `firstUnprocessedIndex`).
                            // When the whole early batch is done, wait for the full list instead.
                            let earlyStart = Self.firstUnprocessedIndex(in: partial, skipICloud: skipICloud)
                            guard earlyStart < partial.count else { return false }
                            self.reviewAssets = partial
                            self.currentIndex = earlyStart
                            self.recalculateCountsFromStores()
                            let storedTotal = savedProgress.originalTotalCount
                            self.originalTotalCount = storedTotal > 0 ? storedTotal : partial.count
                            self.saveProgress()
                            self.refreshStack()
                            self.hideSkeletonLoading()

                            self.showInitialICloudWarning()
                            Task {
                                try? await Task.sleep(nanoseconds: 500_000_000)
                                self.prefetchUpcoming()
                            }
                            return true
                        }
                        if didShow { shownInitialBatch = true }

                    case .completed(let assets):
                        processedAssets = assets
                    case .cancelled:
                        return
                    }
                }

                reviewAssets = processedAssets

                if shownInitialBatch {
                    // Cards already visible, silently expand the array and update stats
                    guard !Task.isCancelled else { return }
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        self.reviewAssets = reviewAssets
                        self.recalculateCountsFromStores()
                        let storedTotal = savedProgress.originalTotalCount
                        self.originalTotalCount = max(
                            storedTotal > 0 ? storedTotal : reviewAssets.count,
                            reviewAssets.count)
                        self.saveProgress()
                        self.updateStats()

                        // Safety net: if all remaining were skipped in the early batch and
                        // completion wasn't shown yet, trigger it now
                        if self.currentIndex >= reviewAssets.count && !reviewAssets.isEmpty {
                            self.showCompletionSummary()
                        }
                    }
                    return
                }
            }

            if Task.isCancelled { return }

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.loadingIndicator.stopAnimating()
                self.reviewAssets = reviewAssets

                if reviewAssets.isEmpty {
                    self.hideSkeletonLoading()
                    self.showEmptyState()
                } else {
                    self.markNonEmptyFilterNotFinished()

                    // Start at the first unprocessed asset, not the saved index (see `firstUnprocessedIndex`)
                    self.currentIndex = Self.firstUnprocessedIndex(in: reviewAssets, skipICloud: skipICloud)
                    self.recalculateCountsFromStores()

                    if currentFilterContext != .none {
                        self.originalTotalCount = reviewAssets.count
                    } else {
                        let storedOriginalTotal = savedProgress.originalTotalCount
                        let resolvedOriginalTotal = storedOriginalTotal > 0 ? storedOriginalTotal : reviewAssets.count
                        self.originalTotalCount = max(resolvedOriginalTotal, reviewAssets.count)
                    }

                    self.saveProgress()
                    self.refreshStack()
                    self.hideSkeletonLoading()

                    if self.currentIndex >= reviewAssets.count {
                        self.showCompletionSummary()
                        return
                    }

                    self.showInitialICloudWarning()

                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        self.prefetchUpcoming()
                    }
                }
            }
        }
    }

    /// Index of the first asset still to review: not in the bin, kept or stored, and not an iCloud-only
    /// asset being skipped. `assets.count` when every asset is done.
    ///
    /// The deck always starts from index 0 rather than the saved `currentIndex`, because the asset
    /// array can change between sessions: an older photo is imported (it sorts in before the saved
    /// index), assets before it are really deleted (everything shifts left), or iCloud-only assets
    /// that were skipped become reachable. The stores already decide what is processed, so a scan
    /// from the start never leaves an unreviewed asset behind the deck.
    static func firstUnprocessedIndex(in assets: [ReviewAsset], skipICloud: Bool) -> Int {
        let deleteBin = DeleteBinStore.shared
        let keptStore = KeptAssetsStore.shared
        let willBeStored = WillBeStoredStore.shared
        return assets.firstIndex { reviewAsset in
            let id = reviewAsset.localIdentifier
            let isProcessed = deleteBin.hasAssetId(id) || keptStore.hasAssetId(id) || willBeStored.hasAssetId(id)
            return !(isProcessed || (skipICloud && reviewAsset.isCloudOnly))
        } ?? assets.count
    }

    /// Check if an asset has already been processed (kept, deleted, or stored)
    func isAssetProcessed(_ asset: PHAsset) -> Bool {
        let identifier = asset.localIdentifier
        return deleteBinStore.hasAssetId(identifier) || KeptAssetsStore.shared.hasAssetId(identifier)
            || willBeStoredStore.hasAssetId(identifier)
    }

    /// Check if an asset should be skipped (processed OR iCloud-only when skip setting is on)
    func shouldSkipAsset(_ reviewAsset: ReviewAsset) -> Bool {
        if isAssetProcessed(reviewAsset.asset) {
            return true
        }

        if settingsStore.skipICloudPhotos && !settingsStore.allowInternetAccess {
            if reviewAsset.isCloudOnly {
                return true
            }
        }

        return false
    }

    /// Check if the current month has iCloud-only assets (for showing initial warning)
    func checkForICloudOnlyAssets() -> Bool {
        guard !settingsStore.allowInternetAccess else { return false }

        for reviewAsset in reviewAssets {
            if reviewAsset.isCloudOnly && !isAssetProcessed(reviewAsset.asset) {
                return true
            }
        }
        return false
    }

    /// Advances the current index until it points to an unprocessed (and non-skipped) asset or end of list
    func advanceToFirstUnprocessedIndex() {
        var checkedCount = 0
        let maxChecks = reviewAssets.count

        while currentIndex < reviewAssets.count && checkedCount < maxChecks {
            let reviewAsset = reviewAssets[currentIndex]
            if shouldSkipAsset(reviewAsset) {
                currentIndex += 1
            } else {
                return
            }
            checkedCount += 1
        }
    }

    // MARK: - Stack Management

    /// Indices of the next `count` assets the deck shows, from the current one on. Assets already
    /// processed (or skipped iCloud ones) are left out, so the cards behind the top one show the
    /// next assets still to review rather than hiding. `reviewAssets.count` pads the rest, which
    /// hides those cards.
    func deckIndices(count: Int) -> [Int] {
        var indices: [Int] = []
        var index = currentIndex
        while indices.count < count && index < reviewAssets.count {
            if !shouldSkipAsset(reviewAssets[index]) { indices.append(index) }
            index += 1
        }
        while indices.count < count { indices.append(reviewAssets.count) }
        return indices
    }

    func refreshStack() {
        let indices = deckIndices(count: cardStack.count)
        for (i, card) in cardStack.enumerated() {
            configureCard(card, at: indices[(cardStack.count - 1) - i])
        }
        // Undo and the history sheet move the deck back too, so the year session's title follows
        updateTitleForYearSession()

        layoutCards()
        updateStats()

        // Handle Video for Top Card
        if currentIndex < reviewAssets.count {
            let topReviewAsset = reviewAssets[currentIndex]
            let topAsset = topReviewAsset.asset
            let isCloudOnlyVideo = topAsset.mediaType == .video && topReviewAsset.isCloudOnly && !settingsStore.allowInternetAccess
            if topAsset.mediaType == .video && !isCloudOnlyVideo {
                displayVideo(asset: topAsset)
            } else {
                cleanupVideo()
                videoController.controlsContainer.alpha = 0
                videoController.controlsContainer.isHidden = true
                videoController.controlsContainer.isUserInteractionEnabled = false
                videoController.playPauseButton.alpha = 0
                videoController.playPauseButton.isHidden = true
                videoController.playPauseButton.isUserInteractionEnabled = false
            }
        }
    }

    /// `placeholderImages` (asset id → image already on screen) fills the card until its own
    /// image loads.
    func configureCard(_ card: SwipeCardView, at index: Int, placeholderImages: [String: UIImage] = [:]) {
        guard index < reviewAssets.count else {
            card.configure(with: nil)
            card.isHidden = true
            return
        }

        let reviewAsset = reviewAssets[index]
        let asset = reviewAsset.asset

        if shouldSkipAsset(reviewAsset) {
            card.configure(with: nil)
            card.isHidden = true
            return
        }

        card.isHidden = false
        card.assetIdentifier = asset.localIdentifier
        card.mediaType = asset.mediaType == .video ? .video : .photo
        card.contentAspectRatio = asset.pixelHeight > 0
            ? CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight) : nil
        card.setPlaceholder(.none)
        if let image = placeholderImages[asset.localIdentifier] {
            card.configure(with: image)
        }

        if let oldRequestID = imageRequestIDs[card.assetIdentifier ?? ""] {
            imageCache.cancelRequest(oldRequestID)
        }

        let isTopCard = (index == currentIndex)
        let quality: ImageCacheService.ImageQuality = isTopCard ? .full : .preview

        let screenSize = view.bounds.size

        card.setICloudBadgeVisible(false)

        let isCloudOnly = reviewAsset.isCloudOnly

        let requestID = autoreleasepool {
            imageCache.loadImage(
                for: asset,
                quality: quality,
                screenSize: screenSize,
                allowNetworkAccess: SettingsStore.shared.allowInternetAccess
            ) { [weak card, weak self] image, isInCloud, _ in

                guard let card = card, let self = self,
                    card.assetIdentifier == asset.localIdentifier
                else { return }

                autoreleasepool {
                    DispatchQueue.main.async {
                        if let image = image {
                            card.configure(with: image)
                            card.setPlaceholder(.none)

                            let showLowQualityBadge = isInCloud && !self.settingsStore.allowInternetAccess
                            card.setICloudBadgeVisible(showLowQualityBadge)
                        } else {
                            if isInCloud && !self.settingsStore.allowInternetAccess {
                                self.loadThumbnailFallback(for: asset, card: card, index: index)
                            } else {
                                card.setPlaceholder(.contentUnavailable)
                            }
                        }
                    }
                }
            }
        }

        if requestID != PHInvalidImageRequestID {
            imageRequestIDs[asset.localIdentifier] = requestID
        }

        applyBadges(to: card, reviewAsset: reviewAsset)
        if usesFannedDeckLayout {
            applyCardSizing()
        }

        let isVideo = asset.mediaType == .video
        if isVideo && isCloudOnly && !settingsStore.allowInternetAccess {
            card.setICloudBadgeVisible(true)
        }
    }

    /// Loads a low-quality thumbnail as fallback for iCloud photos when network is disabled
    func loadThumbnailFallback(for asset: PHAsset, card: SwipeCardView, index: Int) {
        let thumbnailSize = CGSize(width: 400, height: 400)

        var hasSucceeded = false

        imageCache.loadImage(
            for: asset,
            quality: .thumbnail,
            screenSize: thumbnailSize,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        ) { [weak card, weak self] thumbnailImage, _, _ in
            guard let card = card, let self = self,
                card.assetIdentifier == asset.localIdentifier
            else { return }

            if hasSucceeded { return }

            DispatchQueue.main.async {
                if let thumbnail = thumbnailImage {
                    hasSucceeded = true
                    card.configure(with: thumbnail)
                    card.setPlaceholder(.none)
                    card.setICloudBadgeVisible(true)
                } else if !hasSucceeded {
                    card.setPlaceholder(.iCloudUnavailable)
                    card.setICloudBadgeVisible(false)
                    if index == self.currentIndex {
                        self.showPerCardICloudWarning(for: asset)
                    }
                }
            }
        }
    }

    func prefetchUpcoming() {
        let assetsToPrefetch = deckIndices(count: 4).dropFirst()
            .filter { $0 < reviewAssets.count }
            .map { reviewAssets[$0].asset }
        guard !assetsToPrefetch.isEmpty else { return }

        let screenSize = view.bounds.size
        imageCache.startCaching(assets: assetsToPrefetch, quality: .preview, screenSize: screenSize)
    }
}

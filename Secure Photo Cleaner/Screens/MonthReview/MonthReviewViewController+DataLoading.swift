//
//  MonthReviewViewController+DataLoading.swift
//  Secure Photo Cleaner
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

            if let preComputed = preComputed {
                reviewAssets = preComputed
            } else {
                var assets: [PHAsset]
                if let preSorted = preSorted {
                    assets = preSorted
                } else {
                    let monthAssets = await service.fetchPhotos(
                        forMonthKey: currentMonthKey, mediaType: currentMediaType)

                    switch currentFilterContext {
                    case .none:
                        assets = monthAssets
                    case .screenshots:
                        assets = monthAssets.filter { $0.mediaSubtypes.contains(.photoScreenshot) }
                    case .screenRecordings:
                        assets = monthAssets.filter { $0.mediaSubtypes.contains(.videoScreenRecording) }
                    case .slowMotion:
                        assets = monthAssets.filter { $0.mediaSubtypes.contains(.videoHighFrameRate) }
                    case .timeLapse:
                        assets = monthAssets.filter { $0.mediaSubtypes.contains(.videoTimelapse) }
                    case .largeFiles, .eyesClosed:
                        assets = monthAssets
                    }
                }

                if Task.isCancelled { return }

                var processedAssets: [ReviewAsset] = []
                let stream = await PhotoProcessor.shared.processAssets(assets)

                for await result in stream {
                    switch result {
                    case .progress:
                        break
                    case .completed(let assets):
                        processedAssets = assets
                    case .cancelled:
                        return
                    }
                }

                reviewAssets = processedAssets
            }

            if Task.isCancelled { return }

            let deleteBin = DeleteBinStore.shared
            let keptStore = KeptAssetsStore.shared
            let willBeStored = WillBeStoredStore.shared
            let skipICloud = SettingsStore.shared.skipICloudPhotos && !SettingsStore.shared.allowInternetAccess

            let progress = ReviewProgressStore.shared.getProgress(
                forMonthKey: currentProgressKey, mediaType: currentMediaType)
            let maxIndex = max(0, reviewAssets.count - 1)
            var startIndex = min(progress.currentIndex, maxIndex)

            for i in startIndex ..< reviewAssets.count {
                let reviewAsset = reviewAssets[i]
                let id = reviewAsset.localIdentifier
                let isProcessed = deleteBin.hasAssetId(id) || keptStore.hasAssetId(id) || willBeStored.hasAssetId(id)
                let shouldSkip = isProcessed || (skipICloud && reviewAsset.isCloudOnly)

                if !shouldSkip {
                    startIndex = i
                    break
                }

                if i == reviewAssets.count - 1 {
                    startIndex = reviewAssets.count
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

                    self.currentIndex = startIndex
                    //                    print("[FILTER-STATS] loadPhotos — filter=\(currentFilterContext), progressKey=\(currentProgressKey), startIndex=\(startIndex), totalAssets=\(reviewAssets.count)")
                    //                    print("[FILTER-STATS] loadPhotos — savedProgress: deleted=\(progress.deletedCount), kept=\(progress.keptCount), stored=\(progress.storedCount), reviewed=\(progress.reviewedCount), originalTotal=\(progress.originalTotalCount)")

                    self.recalculateCountsFromStores()

                    if currentFilterContext != .none {
                        self.originalTotalCount = reviewAssets.count
                    } else {
                        let storedOriginalTotal = progress.originalTotalCount
                        let resolvedOriginalTotal = storedOriginalTotal > 0 ? storedOriginalTotal : reviewAssets.count
                        self.originalTotalCount = max(resolvedOriginalTotal, reviewAssets.count)
                    }

                    //                    print("[FILTER-STATS] loadPhotos — after recalculate: deleted=\(self.deletedCount), kept=\(self.keptCount), stored=\(self.storedCount), originalTotal=\(self.originalTotalCount)")

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

    func refreshStack() {
        for (i, card) in cardStack.enumerated() {
            let offset = (cardStack.count - 1) - i
            let indexToLoad = currentIndex + offset
            configureCard(card, at: indexToLoad)
        }

        let hiddenCount = cardStack.filter { $0.isHidden }.count
        print(
            "[REFRESH DEBUG] After refreshStack: \(hiddenCount)/\(cardStack.count) cards hidden, currentIndex: \(currentIndex)"
        )

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

    func configureCard(_ card: SwipeCardView, at index: Int) {
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
        card.setPlaceholder(.none)

        if let oldRequestID = imageRequestIDs[card.assetIdentifier ?? ""] {
            imageManager.cancelImageRequest(oldRequestID)
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

        // file size badge
        let isLargeFilesMode = filterContext == .largeFiles
        let isVideo = asset.mediaType == .video

        if isLargeFilesMode || isVideo || isSizeBadgeOpen {
            let formattedSize = reviewAsset.fileSize.formattedBytes()
            card.configureSize(formattedSize)
        } else {
            card.configureSize(nil)
        }

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
        let prefetchCount = min(3, reviewAssets.count - currentIndex - 1)
        guard prefetchCount > 0 else { return }

        var assetsToPrefetch: [PHAsset] = []
        for offset in 1 ... prefetchCount {
            let nextIndex = currentIndex + offset
            guard nextIndex < reviewAssets.count else { break }
            assetsToPrefetch.append(reviewAssets[nextIndex].asset)
        }

        let screenSize = view.bounds.size
        imageCache.startCaching(assets: assetsToPrefetch, quality: .preview, screenSize: screenSize)
    }
}

//
//  MonthReviewViewController+Swipe.swift
//  Purgio
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import Photos
import UIKit

private let alwaysShowStoreTutorial = false

extension MonthReviewViewController {
    
    enum SwipeDirection {
        case left, right, up
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard !isLoadingPhotos else { return }
        guard !isAnimatingSwipe else { return }

        guard let topCard = cardStack.last(where: { !$0.isHidden }) else { return }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            topCard.layer.removeAllAnimations()

            UIView.animate(withDuration: 0.2) {
                self.videoController.playPauseButton.alpha = 0
                self.videoController.controlsContainer.alpha = 0
                topCard.setBadgeAlpha(0)
            }

        case .changed:
            let rotation = translation.x / view.bounds.width * 0.2
            topCard.transform = CGAffineTransform(translationX: translation.x, y: translation.y)
                .rotated(by: rotation)
            
            let absX = abs(translation.x)
            let absY = abs(translation.y)
            let minThreshold: CGFloat = 15.0 // Minimum movement before showing gradient

            if absX > minThreshold || absY > minThreshold {
                if absY > absX && translation.y < 0 {
                    let verticalProgress = min(abs(translation.y) / 200.0, 1.0)
                    topGradient.alpha = verticalProgress
                    leftGradient.alpha = 0
                    rightGradient.alpha = 0
                } else if absX > absY {
                    let progress = min(absX / 200.0, 1.0)
                    if translation.x > 0 { // Right = Keep (Green)
                        rightGradient.alpha = progress
                        leftGradient.alpha = 0
                        topGradient.alpha = 0
                    } else { // Left = Delete (Red)
                        leftGradient.alpha = progress
                        rightGradient.alpha = 0
                        topGradient.alpha = 0
                    }
                } else {
                    // Below threshold or downward movement - no gradient
                    leftGradient.alpha = 0
                    rightGradient.alpha = 0
                    topGradient.alpha = 0
                }
            } else {
                // Below threshold - no gradient
                leftGradient.alpha = 0
                rightGradient.alpha = 0
                topGradient.alpha = 0
            }

        case .ended, .cancelled:
            let threshold: CGFloat = 100
            let velocityThreshold: CGFloat = 800

            let isUpSwipe = translation.y < -threshold || velocity.y < -velocityThreshold

            if isUpSwipe {
                completeSwipe(direction: .up)
            } else {
                let shouldSwipeHorizontal = abs(translation.x) > threshold || abs(velocity.x) > velocityThreshold

                if shouldSwipeHorizontal {
                    let isRightSwipe: Bool
                    if abs(translation.x) > 10 {
                        isRightSwipe = translation.x > 0
                    } else {
                        isRightSwipe = velocity.x > 0
                    }
                    completeSwipe(direction: isRightSwipe ? .right : .left)
                } else {
                    // Not enough movement, spring back
                    UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.3, options: [.allowUserInteraction], animations: {
                        topCard.transform = .identity
                        self.leftGradient.alpha = 0
                        self.rightGradient.alpha = 0
                        self.topGradient.alpha = 0

                        // Show video controls again if it's a video
                        if self.currentIndex < self.reviewAssets.count {
                            let asset = self.reviewAssets[self.currentIndex].asset
                            if asset.mediaType == .video {
                                self.videoController.playPauseButton.alpha = 1.0
                                self.videoController.controlsContainer.alpha = self.videoController.isPlaying ? 0.5 : 1.0
                            }
                        }

                        topCard.setBadgeAlpha(1.0)
                    })
                }
            }
        default: break
        }
    }

    func completeSwipe(direction: SwipeDirection) {
        cleanupVideo()
        haptics.impact()
        isAnimatingSwipe = true

        guard let topCard = cardStack.last else { return }

        switch direction {
        case .left:
            let offScreenX: CGFloat = -(view.bounds.width + 100)
            UIView.animate(withDuration: 0.4, animations: {
                topCard.transform = CGAffineTransform(translationX: offScreenX, y: 50).rotated(by: -0.2)
                self.leftGradient.alpha = 1.0
            }) { _ in
                self.advanceToNext(markForDeletion: true, willBeStored: false)
            }

        case .right:
            let offScreenX: CGFloat = view.bounds.width + 100
            UIView.animate(withDuration: 0.4, animations: {
                topCard.transform = CGAffineTransform(translationX: offScreenX, y: 50).rotated(by: 0.2)
                self.rightGradient.alpha = 1.0
            }) { _ in
                self.advanceToNext(markForDeletion: false, willBeStored: false)
            }

        case .up:
            let offScreenY: CGFloat = -(view.bounds.height + 100)
            UIView.animate(withDuration: 0.4, animations: {
                topCard.transform = CGAffineTransform(translationX: 0, y: offScreenY)
                self.topGradient.alpha = 1.0
            }) { _ in
                self.advanceToNext(markForDeletion: false, willBeStored: true)
            }
        }
    }

    func advanceToNext(markForDeletion: Bool, willBeStored: Bool) {
        guard currentIndex < reviewAssets.count else { return }
        let reviewAsset = reviewAssets[currentIndex]
        let asset = reviewAsset.asset
        let assetSize = reviewAsset.fileSize

        let actionType: UndoAction.ActionType
        if willBeStored {
            actionType = .store
        } else if markForDeletion {
            actionType = .delete
        } else {
            actionType = .keep
        }

        historyManager.recordAction(actionType, for: asset.localIdentifier, at: currentIndex, assetSize: assetSize)

        if willBeStored {
            willBeStoredStore.addAssetId(asset.localIdentifier)
            storedCount += 1

            Task {
                let success = await photoLibraryService.addAssetToWillBeStoredAlbum(asset: asset)
                if !success {
                    print("Failed to add asset to 'Will Be Stored' album")
                }
            }

            // Show store tutorial on first-ever store action
            if alwaysShowStoreTutorial || !settingsStore.hasShownStoreTutorial {
                settingsStore.hasShownStoreTutorial = true
                let tutorial = StoreTutorialSheetViewController(storedAsset: asset)
                present(tutorial, animated: true)
            }
        } else if markForDeletion {
            deleteBinStore.addAssetId(asset.localIdentifier)
            deletedCount += 1
            statsStore.recordDeletion(for: mediaType, bytes: assetSize)

            sessionIncrementCount += 1
            updateGlobalBinButtonIncrement()
        } else {
            keptCount += 1
            KeptAssetsStore.shared.addAssetId(asset.localIdentifier)
        }

        statsStore.recordReview(for: mediaType)
        currentIndex += 1
        
        advanceToFirstUnprocessedIndex()
//        print("[FILTER-STATS] advanceToNext — action=\(actionType), filter=\(filterContext), newIndex=\(currentIndex), deleted=\(deletedCount), kept=\(keptCount), stored=\(storedCount)")
        saveProgress()

        let recycledCard = cardStack.removeLast()

        if let oldAssetId = recycledCard.assetIdentifier,
           let requestID = imageRequestIDs[oldAssetId] {
            imageManager.cancelImageRequest(requestID)
            imageRequestIDs.removeValue(forKey: oldAssetId)
        }

        recycledCard.reset()

        // Keep cache window of current + next 3 only
        if currentIndex > 3 {
            let oldIndex = currentIndex - 4
            if oldIndex >= 0 && oldIndex < reviewAssets.count {
                let oldAsset = reviewAssets[oldIndex].asset
                imageCache.stopCaching(assets: [oldAsset], quality: .full, screenSize: view.bounds.size)
                imageCache.stopCaching(assets: [oldAsset], quality: .preview, screenSize: view.bounds.size)
            }
        }

        cardStack.insert(recycledCard, at: 0)
        cardContainerView.sendSubviewToBack(recycledCard)

        let newBottomIndex = currentIndex + 2
        configureCard(recycledCard, at: newBottomIndex)

        let bottomReverseIndex = CGFloat(cardStack.count - 1)
        let bottomScale = 1.0 - (bottomReverseIndex * 0.05)
        let bottomTranslationY = bottomReverseIndex * 10
        recycledCard.transform = CGAffineTransform(scaleX: bottomScale, y: bottomScale)
            .translatedBy(x: 0, y: bottomTranslationY)
        recycledCard.alpha = 1.0
        
        UIView.animate(withDuration: 0.3, animations: {
            self.layoutCards()
            self.leftGradient.alpha = 0
            self.rightGradient.alpha = 0
            self.topGradient.alpha = 0
        }, completion: { _ in
            self.isAnimatingSwipe = false
        })

        updateStats()

        if currentIndex < reviewAssets.count {
            let topAsset = reviewAssets[currentIndex].asset
            if topAsset.mediaType == .video {
                displayVideo(asset: topAsset)
            }
        }

        prefetchUpcoming()

        if currentIndex >= reviewAssets.count {
             showCompletionSummary()
        }
    }
}

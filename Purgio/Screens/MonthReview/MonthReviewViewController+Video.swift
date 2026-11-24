//
//  MonthReviewViewController+Video.swift
//  Purgio
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import Photos
import UIKit

extension MonthReviewViewController {
    private enum VideoControlsLayout {
        static let overlayInset: CGFloat = 12
        static let overlayHeight: CGFloat = 50
        /// Split capsules (iPhone Duo sideways, see +Landscape)
        static let splitInset: CGFloat = GeneralConstants.EdgePadding.medium
        static let splitHeight: CGFloat = 52
    }

    func setupVideoControls() {
        installOverlayPlayButton()
        cardContainerView.addSubview(videoController.controlsContainer)

        let controls = videoController.controlsContainer
        videoControlsOverlayConstraints = [
            controls.leadingAnchor.constraint(
                equalTo: cardContainerView.leadingAnchor, constant: VideoControlsLayout.overlayInset),
            controls.trailingAnchor.constraint(
                equalTo: cardContainerView.trailingAnchor, constant: -VideoControlsLayout.overlayInset),
            controls.bottomAnchor.constraint(
                equalTo: cardContainerView.bottomAnchor, constant: -VideoControlsLayout.overlayInset),
            controls.heightAnchor.constraint(equalToConstant: VideoControlsLayout.overlayHeight)
        ]
        videoControlsSplitConstraints = [
            controls.leadingAnchor.constraint(
                equalTo: cardContainerView.leadingAnchor, constant: VideoControlsLayout.splitInset),
            controls.trailingAnchor.constraint(
                equalTo: cardContainerView.trailingAnchor, constant: -VideoControlsLayout.splitInset),
            controls.bottomAnchor.constraint(
                equalTo: cardContainerView.bottomAnchor, constant: -VideoControlsLayout.splitInset),
            controls.heightAnchor.constraint(equalToConstant: VideoControlsLayout.splitHeight)
        ]
        NSLayoutConstraint.activate(videoControlsOverlayConstraints)
    }

    /// The 80pt play button centered on the card. Also called when the split controls hand
    /// the button back (moving it between views drops its old constraints).
    func installOverlayPlayButton() {
        let button = videoController.playPauseButton
        if button.superview !== cardContainerView {
            if let controls = videoController.controlsContainer.superview, controls === cardContainerView {
                cardContainerView.insertSubview(button, belowSubview: videoController.controlsContainer)
            } else {
                cardContainerView.addSubview(button)
            }
        }
        NSLayoutConstraint.deactivate(overlayPlayButtonConstraints)

        let playPauseCenterX = button.centerXAnchor.constraint(equalTo: cardContainerView.centerXAnchor)
        playPauseCenterXConstraint = playPauseCenterX
        overlayPlayButtonConstraints = [
            playPauseCenterX,
            button.centerYAnchor.constraint(equalTo: cardContainerView.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 80),
            button.heightAnchor.constraint(equalToConstant: 80)
        ]
        NSLayoutConstraint.activate(overlayPlayButtonConstraints)
    }

    /// Sideways on iPhone Duo: two capsules split at the fold instead of the overlay.
    func setVideoControlsSplit(_ isSplit: Bool) {
        if isSplit {
            NSLayoutConstraint.deactivate(overlayPlayButtonConstraints + videoControlsOverlayConstraints)
            videoController.setControlsLayout(.split)
            NSLayoutConstraint.activate(videoControlsSplitConstraints)
        } else {
            NSLayoutConstraint.deactivate(videoControlsSplitConstraints)
            videoController.setControlsLayout(.overlay)
            NSLayoutConstraint.activate(videoControlsOverlayConstraints)
            installOverlayPlayButton()
        }
    }

    func displayVideo(asset: PHAsset) {
        videoController.cleanup()

        guard let topCard = cardStack.last else { return }

        if topCard.isPlaceholderVisible {
            videoController.playPauseButton.isHidden = true
            videoController.playPauseButton.isUserInteractionEnabled = false
            videoController.controlsContainer.isHidden = true
            videoController.controlsContainer.isUserInteractionEnabled = false
            return
        }

        videoController.playPauseButton.isHidden = false
        videoController.playPauseButton.isUserInteractionEnabled = true
        videoController.controlsContainer.isHidden = false
        videoController.controlsContainer.isUserInteractionEnabled = true

        videoController.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                if let layer = self.videoController.playerLayer {
                    layer.frame = topCard.bounds
                    topCard.embedVideoLayer(layer)
                }
                UIView.animate(withDuration: 0.3) {
                    self.videoController.playPauseButton.alpha = 1.0
                    self.showSplitControlsWithPlayButton()
                }
            case .failed:
                self.videoController.controlsContainer.alpha = 0
                if let topCard = self.cardStack.last {
                    if topCard.hasImage {
                        self.videoController.playPauseButton.alpha = 1.0
                        self.showSplitControlsWithPlayButton()
                    } else {
                        self.videoController.playPauseButton.alpha = 0
                        self.videoController.playPauseButton.isHidden = true
                        self.videoController.playPauseButton.isUserInteractionEnabled = false
                        self.videoController.controlsContainer.isHidden = true
                        self.videoController.controlsContainer.isUserInteractionEnabled = false
                        topCard.setPlaceholder(.iCloudUnavailable)
                    }
                }
            default:
                break
            }
        }

        videoController.onICloudPlayAttempt = { [weak self] in
            guard let self = self else { return }
            self.showICloudBadgeTapSheet()
        }

        if let topCard = cardStack.last, topCard.isICloudBadgeVisible, !settingsStore.allowInternetAccess {
            videoController.iCloudLoadFailed = true
            videoController.playPauseButton.alpha = 1.0
            videoController.controlsContainer.alpha = 0
            showSplitControlsWithPlayButton()
            return
        }

        videoController.loadVideo(
            from: asset,
            using: imageManager,
            allowNetworkAccess: settingsStore.allowInternetAccess
        )
    }

    /// The split controls hold the play button, so they show whenever it does.
    /// (The overlay bar only appears once playback starts.)
    private func showSplitControlsWithPlayButton() {
        guard videoController.controlsLayout == .split else { return }
        videoController.controlsContainer.alpha = 1.0
    }

    func cleanupVideo() {
        videoController.cleanup()
    }
}

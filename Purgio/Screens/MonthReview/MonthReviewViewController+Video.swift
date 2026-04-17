//
//  MonthReviewViewController+Video.swift
//  Purgio
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import Photos
import UIKit

extension MonthReviewViewController {
    func setupVideoControls() {
        cardContainerView.addSubview(videoController.playPauseButton)
        cardContainerView.addSubview(videoController.controlsContainer)

        NSLayoutConstraint.activate([
            videoController.playPauseButton.centerXAnchor.constraint(equalTo: cardContainerView.centerXAnchor),
            videoController.playPauseButton.centerYAnchor.constraint(equalTo: cardContainerView.centerYAnchor),
            videoController.playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            videoController.playPauseButton.heightAnchor.constraint(equalToConstant: 80),

            videoController.controlsContainer.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor, constant: 12),
            videoController.controlsContainer.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor, constant: -12),
            videoController.controlsContainer.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor, constant: -12),
            videoController.controlsContainer.heightAnchor.constraint(equalToConstant: 50)
        ])
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
                }
            case .failed:
                self.videoController.controlsContainer.alpha = 0
                if let topCard = self.cardStack.last {
                    if topCard.hasImage {
                        self.videoController.playPauseButton.alpha = 1.0
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
            return
        }

        videoController.loadVideo(
            from: asset,
            using: imageManager,
            allowNetworkAccess: settingsStore.allowInternetAccess
        )
    }

    func cleanupVideo() {
        videoController.cleanup()
    }
}

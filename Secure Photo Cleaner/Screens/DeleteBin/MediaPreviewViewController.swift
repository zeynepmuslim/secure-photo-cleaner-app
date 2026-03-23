//
//  MediaPreviewViewController.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import AVFoundation
import Photos
import SwiftUI
import UIKit

final class MediaPreviewViewController: UIViewController {

    var onRemove: (() -> Void)?
    var onUndo: (() -> Void)?
    var onDeleteNow: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .clear
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        return view
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .clear
        return imageView
    }()

    private let closeButton = CloseButton()

    private let actionButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configure(
            title: "Remove from Bin",
            systemImage: "trash.slash",
            style: .prominent,
            backgroundColor: .green100
        )
        return button
    }()

    private let deleteNowButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.configure(
            title: "Delete Now",
            systemImage: "trash.fill",
            style: .prominent,
            backgroundColor: .systemRed
        )
        return button
    }()

    private let buttonsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private let videoController = VideoPlayerController(configuration: .init(
        videoGravity: .resizeAspect
    ))

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.color = .label
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private let imageManager = PHCachingImageManager()

    private let asset: PHAsset
    private var wasRemoved = false
    var previewImage: UIImage?

    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
        configureSheet()
    }

    private func configureSheet() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        loadMedia()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        videoController.cleanup()
        onDismiss?()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoController.playerLayer?.frame = containerView.bounds
    }

    private func setupUI() {
        if #available(iOS 26.0, *) {
            view.backgroundColor = .clear
        } else {
            view.backgroundColor = .systemBackground
        }

        actionButton.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
        deleteNowButton.addTarget(self, action: #selector(handleDeleteNow), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)

        containerView.addSubview(imageView)
        containerView.addSubview(videoController.playPauseButton)
        containerView.addSubview(videoController.controlsContainer)

        let isVideo = asset.mediaType == .video
        videoController.playPauseButton.isHidden = !isVideo
        videoController.controlsContainer.isHidden = !isVideo

        buttonsStack.addArrangedSubview(actionButton)
        buttonsStack.addArrangedSubview(deleteNowButton)

        view.addSubview(containerView)
        view.addSubview(buttonsStack)
        view.addSubview(closeButton)
        view.addSubview(loadingIndicator)
    }

    private func setupConstraint() {
        let buttonHeight: CGFloat = GeneralConstants.ButtonSize.mediumLarge

        NSLayoutConstraint.activate([
            buttonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonsStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            actionButton.heightAnchor.constraint(equalToConstant: buttonHeight),
            deleteNowButton.heightAnchor.constraint(equalToConstant: buttonHeight),

            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(equalTo: buttonsStack.topAnchor, constant: -16),

            imageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            loadingIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            videoController.playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            videoController.playPauseButton.heightAnchor.constraint(equalToConstant: 80),
            videoController.playPauseButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            videoController.playPauseButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),

            videoController.controlsContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            videoController.controlsContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            videoController.controlsContainer.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            videoController.controlsContainer.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func loadMedia() {
        if let previewImage {
            imageView.image = previewImage
            return
        }

        loadingIndicator.startAnimating()

        if asset.mediaType == .video {
            loadVideo()
        } else {
            loadImage()
        }
    }

    private func loadImage() {
        let targetSize = CGSize(
            width: view.bounds.width,
            height: view.bounds.height
        )

        ImageCacheService.shared.loadImage(
            for: asset,
            quality: .full,
            screenSize: targetSize,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        ) { [weak self] image, _, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.loadingIndicator.stopAnimating()

                if let image = image {
                    self.imageView.image = image
                } else {
                    self.showError(message: "Failed to load image")
                }
            }
        }
    }

    private func loadVideo() {
        imageView.isHidden = true

        videoController.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.loadingIndicator.stopAnimating()
                if let layer = self.videoController.playerLayer {
                    layer.frame = self.containerView.bounds
                    self.containerView.layer.insertSublayer(layer, at: 0)
                }
            case .failed:
                self.loadingIndicator.stopAnimating()
                self.showError(message: "Failed to load video")
                self.videoController.playPauseButton.isHidden = true
            case .ended:
                UIView.animate(withDuration: 0.3) {
                    self.videoController.controlsContainer.alpha = 0
                }
            default:
                break
            }
        }

        videoController.loadVideo(
            from: asset,
            using: imageManager,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        )
    }

    private func showError(message: String) {
        let label = UILabel()
        label.text = message
        label.textAlignment = .center
        label.textColor = .systemGray
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func showUndoState() {
        deleteNowButton.isUserInteractionEnabled = false
        actionButton.animateConfigure(
            title: "Undo",
            systemImage: "arrow.uturn.backward",
            style: .regular,
            backgroundColor: .secondarySystemFill,
            foregroundColor: .label
        )
        UIView.animate(withDuration: 0.3) {
            self.deleteNowButton.alpha = 0.45
        }
    }

    private func showActionState() {
        deleteNowButton.isUserInteractionEnabled = true
        actionButton.animateConfigure(
            title: "Remove from Bin",
            systemImage: "trash.slash",
            style: .prominent,
            backgroundColor: .green100
        )
        UIView.animate(withDuration: 0.3) {
            self.deleteNowButton.alpha = 1
        }
    }

    // MARK: - Actions
    @objc private func handleActionTap() {
        if wasRemoved {
            wasRemoved = false
            onUndo?()
            showActionState()
        } else {
            wasRemoved = true
            onRemove?()
            showUndoState()
        }
    }

    @objc private func handleDeleteNow() {
        onDeleteNow?()
    }

    @objc private func handleClose() {
        dismiss(animated: true)
    }

}

@available(iOS 17.0, *)
#Preview {
    let vc = MediaPreviewViewController(asset: PHAsset())
    vc.previewImage = UIImage(named: "exampleImage")
    return vc
}

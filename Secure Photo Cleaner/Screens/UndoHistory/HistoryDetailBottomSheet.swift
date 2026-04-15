//
//  HistoryDetailBottomSheet.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 15.01.2026.
//

import UIKit
import Photos
import AVFoundation

final class HistoryDetailBottomSheet: UIViewController {
    
    var onKeepTapped: (() -> Void)?
    var onDeleteTapped: (() -> Void)?
    var onStoreTapped: (() -> Void)?

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let closeButtonRow : UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        return stack
    }()
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.backgroundColor = .textPrimary.withAlphaComponent(CGFloat(0.2))
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        
        imageView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var keepButton: DynamicGlassButton = {
        createActionButton(title: NSLocalizedString("historyDetail.keep", comment: "Keep action button"), color: .systemGreen)
    }()

    private lazy var deleteButton: DynamicGlassButton = {
        createActionButton(title: NSLocalizedString("historyDetail.delete", comment: "Delete action button"), color: .systemRed)
    }()

    private lazy var storeButton: DynamicGlassButton = {
        createActionButton(title: NSLocalizedString("historyDetail.store", comment: "Store action button"), color: .systemYellow)
    }()

    private let videoOverlayIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "play.fill"))
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    private let fullScreenButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "rectangle.expand.diagonal"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        button.layer.cornerRadius = 4
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let mainStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let sheetVideoController = VideoPlayerController(configuration: .init(
        videoGravity: .resizeAspect,
        layerCornerRadius: 12
    ))
    private let sheetImageManager = PHCachingImageManager()

    private let action: UndoAction
    private let image: UIImage?
    private let mediaType: PHAssetMediaType

    private func createActionButton(title: String, color: UIColor) -> DynamicGlassButton {
        let button = DynamicGlassButton()
        button.configure(
            title: title,
            style: .regular,
            backgroundColor: .secondarySystemFill,
            foregroundColor: color,
            contentInsets: NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        )
        return button
    }
    
    init(action: UndoAction, image: UIImage?, mediaType: PHAssetMediaType = .image) {
        self.action = action
        self.image = image
        self.mediaType = mediaType
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
        configure()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(mainStackView)
        
        mainStackView.addArrangedSubview(closeButtonRow)
        closeButtonRow.addArrangedSubview(closeButton)
        closeButtonRow.addArrangedSubview(UIView.flexibleSpacer())
        
        mainStackView.addArrangedSubview(imageView)
        mainStackView.addArrangedSubview(titleLabel)
        mainStackView.addArrangedSubview(timeLabel)
        
        mainStackView.addArrangedSubview(actionStackView)
        
        actionStackView.addArrangedSubview(keepButton)
        actionStackView.addArrangedSubview(deleteButton)
        actionStackView.addArrangedSubview(storeButton)
        
        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        keepButton.addTarget(self, action: #selector(handleKeepTap), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        storeButton.addTarget(self, action: #selector(handleStoreTap), for: .touchUpInside)
        
        imageView.addSubview(videoOverlayIcon)
        imageView.addSubview(fullScreenButton)

        fullScreenButton.addTarget(self, action: #selector(handleFullScreenTap), for: .touchUpInside)

        videoOverlayIcon.isUserInteractionEnabled = true
        let videoTap = UITapGestureRecognizer(target: self, action: #selector(handleVideoOverlayTap))
        videoOverlayIcon.addGestureRecognizer(videoTap)

        let videoAreaTap = UITapGestureRecognizer(target: self, action: #selector(handleVideoAreaTap))
        imageView.addGestureRecognizer(videoAreaTap)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: GeneralConstants.EdgePadding.medium),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -GeneralConstants.EdgePadding.medium),
            mainStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: GeneralConstants.EdgePadding.medium),
            mainStackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -GeneralConstants.EdgePadding.medium),

            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
            closeButton.leadingAnchor.constraint(equalTo: mainStackView.leadingAnchor),

            videoOverlayIcon.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            videoOverlayIcon.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
            videoOverlayIcon.widthAnchor.constraint(equalToConstant: 40),
            videoOverlayIcon.heightAnchor.constraint(equalToConstant: 40),

            fullScreenButton.topAnchor.constraint(equalTo: imageView.topAnchor, constant: 8),
            fullScreenButton.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -8),
            fullScreenButton.widthAnchor.constraint(equalToConstant: 34),
            fullScreenButton.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.heightAnchor.constraint(equalToConstant: 16),
            timeLabel.heightAnchor.constraint(equalToConstant: 16),
            actionStackView.widthAnchor.constraint(equalTo: mainStackView.widthAnchor),
            actionStackView.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
    
    private func configure() {
        imageView.image = image
        titleLabel.text = action.displayTitle
        timeLabel.text = action.timestamp.timeAgo()
        videoOverlayIcon.isHidden = mediaType != .video
    }
    
    @objc private func handleCloseTap() {
        dismiss(animated: true)
    }
    
    @objc private func handleKeepTap() {
        dismiss(animated: true) { [weak self] in
            self?.onKeepTapped?()
        }
    }
    
    @objc private func handleDeleteTap() {
        dismiss(animated: true) { [weak self] in
            self?.onDeleteTapped?()
        }
    }
    
    @objc private func handleStoreTap() {
        dismiss(animated: true) { [weak self] in
            self?.onStoreTapped?()
        }
    }
    
    @objc private func handleFullScreenTap() {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [action.assetLocalIdentifier], options: PHFetchOptions())
        guard let asset = result.firstObject else { return }
        showFullScreenPreview(for: asset)
    }

    @objc private func handleVideoAreaTap() {
        guard sheetVideoController.playerLayer != nil else { return }
        sheetVideoController.togglePlayPause()
        updateVideoOverlayIcon()
    }

    @objc private func handleVideoOverlayTap() {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [action.assetLocalIdentifier], options: PHFetchOptions())
        guard let asset = result.firstObject else { return }

        if sheetVideoController.playerLayer == nil {
            loadInlineVideo(asset: asset)
        } else {
            sheetVideoController.togglePlayPause()
            updateVideoOverlayIcon()
        }
    }
    
    private func showFullScreenPreview(for asset: PHAsset) {
        let previewVC = HistoryMediaPreviewViewController(asset: asset)
        previewVC.modalPresentationStyle = .overFullScreen
        previewVC.modalTransitionStyle = .coverVertical
        present(previewVC, animated: true)
    }

    private func loadInlineVideo(asset: PHAsset) {
        videoOverlayIcon.isHidden = true

        sheetVideoController.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                if let layer = self.sheetVideoController.playerLayer {
                    layer.frame = self.imageView.bounds
                    self.imageView.layer.addSublayer(layer)
                }
                self.imageView.bringSubviewToFront(self.videoOverlayIcon)
                self.imageView.bringSubviewToFront(self.fullScreenButton)
                self.sheetVideoController.play()
                self.videoOverlayIcon.isHidden = false
                self.updateVideoOverlayIcon()
            case .ended:
                self.updateVideoOverlayIcon()
            case .failed:
                self.videoOverlayIcon.isHidden = false
            default:
                break
            }
        }

        sheetVideoController.loadVideo(
            from: asset,
            using: sheetImageManager,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        )
    }

    private func updateVideoOverlayIcon() {
        let iconName = sheetVideoController.isPlaying ? "pause.fill" : "play.fill"
        videoOverlayIcon.image = UIImage(systemName: iconName)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sheetVideoController.playerLayer?.frame = imageView.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sheetVideoController.cleanup()
    }
}

// MARK: - HistoryMediaPreviewViewController

final class HistoryMediaPreviewViewController: UIViewController {

    // MARK: - Private UI

    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let loadingIndicator = UIActivityIndicatorView(style: .large)

    private let videoController = VideoPlayerController(configuration: .init(
        videoGravity: .resizeAspect
    ))


    private let imageManager = PHCachingImageManager()

    private let asset: PHAsset
    
    init(asset: PHAsset) {
        self.asset = asset
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupUI()
        setupConstraint()
        loadMedia()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        videoController.cleanup()

    }

    deinit {
        videoController.cleanup()
    }
    
    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        
        // Image view
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        scrollView.addSubview(imageView)
        
        // Close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .regular)), for: .normal)
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        view.addSubview(closeButton)
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.color = .white
        loadingIndicator.hidesWhenStopped = true
        view.addSubview(loadingIndicator)
        
        setupVideoControls()

        // Pan gesture for swipe-to-dismiss
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanDismiss(_:)))
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func setupVideoControls() {
        videoController.playPauseButton.alpha = 0
        videoController.controlsContainer.alpha = 0

        view.addSubview(videoController.playPauseButton)
        view.addSubview(videoController.controlsContainer)

        NSLayoutConstraint.activate([
            videoController.playPauseButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            videoController.playPauseButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            videoController.playPauseButton.widthAnchor.constraint(equalToConstant: 80),
            videoController.playPauseButton.heightAnchor.constraint(equalToConstant: 80),

            videoController.controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            videoController.controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            videoController.controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            videoController.controlsContainer.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func loadMedia() {
        loadingIndicator.startAnimating()
        
        if asset.mediaType == .video {
            loadVideo()
        } else {
            loadImage()
        }
    }
    
    private func loadImage() {
        videoController.playPauseButton.isHidden = true
        videoController.controlsContainer.isHidden = true

        let targetSize = CGSize(
            width: view.bounds.width * UIScreen.main.scale,
            height: view.bounds.height * UIScreen.main.scale
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
        scrollView.isUserInteractionEnabled = false

        videoController.onStateChanged = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.loadingIndicator.stopAnimating()
                if let layer = self.videoController.playerLayer {
                    layer.frame = self.view.bounds
                    self.view.layer.insertSublayer(layer, at: 0)
                }
                UIView.animate(withDuration: 0.3) {
                    self.videoController.playPauseButton.alpha = 1.0
                    self.videoController.controlsContainer.alpha = 1.0
                }
            case .failed:
                self.loadingIndicator.stopAnimating()
                self.showError(message: "Failed to load video")
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoController.playerLayer?.frame = view.bounds
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
    
    // MARK: - Actions
    
    @objc private func handleClose() {
        dismiss(animated: true)
    }

    @objc private func handlePanDismiss(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .changed:
            let progress = max(0, translation.y) / view.bounds.height
            view.transform = CGAffineTransform(translationX: 0, y: max(0, translation.y))
        case .ended, .cancelled:
            let shouldDismiss = translation.y > 150 || velocity.y > 1000
            if shouldDismiss {
                UIView.animate(
                    withDuration: 0.6,
                    delay: 0,
                    usingSpringWithDamping: 1.0,
                    initialSpringVelocity: velocity.y / 1000,
                    options: .curveLinear,
                    animations: {
                        self.view.transform = CGAffineTransform(translationX: 0, y: self.view.bounds.height)
                    }
                ) { _ in
                    self.dismiss(animated: true)
                }
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.view.transform = .identity
                    self.view.alpha = 1
                }
            }
        default:
            break
        }
    }
}

// MARK: - UIScrollViewDelegate & UIGestureRecognizerDelegate

extension HistoryMediaPreviewViewController: UIScrollViewDelegate, UIGestureRecognizerDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        // Only begin for primarily downward vertical swipes, and only when not zoomed
        return abs(velocity.y) > abs(velocity.x) && velocity.y > 0 && scrollView.zoomScale <= 1.0
    }
}

#if DEBUG
    import SwiftUI

    private struct HistoryDetailBottomSheetPreview: UIViewControllerRepresentable {
        let actionType: UndoAction.ActionType

        func makeUIViewController(context: Context) -> HistoryDetailBottomSheet {
            HistoryDetailBottomSheet(action: Self.mockAction(actionType), image: Self.placeholderImage())
        }

        func updateUIViewController(_ uiViewController: HistoryDetailBottomSheet, context: Context) {}

        private static func mockAction(_ type: UndoAction.ActionType) -> UndoAction {
            UndoAction(
                id: UUID(),
                actionType: type,
                assetLocalIdentifier: "preview-asset",
                index: 0,
                assetSize: 1024 * 1024 * 3,
                timestamp: Date() + TimeInterval(-3600),
                sessionId: UUID()
            )
        }

        private static func placeholderImage() -> UIImage {
            let size = CGSize(width: 375, height: 280)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                UIColor.systemGray.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
        }
    }

    #Preview("Delete Action") {
        HistoryDetailBottomSheetPreview(actionType: .delete)
    }

    #Preview("Keep Action") {
        HistoryDetailBottomSheetPreview(actionType: .keep)
    }

    #Preview("Store Action") {
        HistoryDetailBottomSheetPreview(actionType: .store)
    }

#endif


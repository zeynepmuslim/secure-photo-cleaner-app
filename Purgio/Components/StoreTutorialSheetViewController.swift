//
//  StoreTutorialSheetViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.03.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let albumRecents = NSLocalizedString("storeTutorial.albumRecents", comment: "Fake album name: Recents")
    static let albumScreenshots = NSLocalizedString("storeTutorial.albumScreenshots", comment: "Fake album name: Screenshots")
    static let albumVideos = NSLocalizedString("storeTutorial.albumVideos", comment: "Fake album name: Videos")
    static let albumFavorites = NSLocalizedString("storeTutorial.albumFavorites", comment: "Fake album name: Favorites")
    static let albumSelfies = NSLocalizedString("storeTutorial.albumSelfies", comment: "Fake album name: Selfies")
    static let albumWillBeStored = NSLocalizedString("undoAction.willBeStored", comment: "Will Be Stored album")
}

private enum WithContentTimings {
    static let cellInsertDelay: TimeInterval = 0.3
    static let cellPopDuration: TimeInterval = 0.5
    static let flyInDelay: TimeInterval = 0.5
    static let slideDuration: TimeInterval = 0.6
    static let popUpDelay: TimeInterval = 0.3
    static let popUpDuration: TimeInterval = 0.15
    static let shrinkDuration: TimeInterval = 0.25
    static let dismissDelay: TimeInterval = 1.0
}

private enum WithoutContentTimings {
    static let cellInsertDelay: TimeInterval = 0.3
    static let cellPopDuration: TimeInterval = 0.5
    static let dismissDelay: TimeInterval = 1.0
}

final class StoreTutorialSheetViewController: UIViewController {

    private struct AlbumItem {
        let title: String
        let sfSymbol: String
        let tint: UIColor
        let showBadge: Bool
    }

    private let storedAsset: PHAsset?
    private var albums: [AlbumItem] = []
    private var dismissWorkItem: DispatchWorkItem?
    private var flyInWorkItem: DispatchWorkItem?
    private var popWorkItem: DispatchWorkItem?
    private var hasStartedFlyIn = false
    #if DEBUG
        private var debugFlyInImage: UIImage?
    #endif

    private var hasContent: Bool {
        #if DEBUG
            if debugFlyInImage != nil { return true }
        #endif
        return storedAsset != nil
    }

    private let topGradient: GradientView = {
        let view = GradientView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "photos-icon")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(FakeAlbumCell.self, forCellWithReuseIdentifier: FakeAlbumCell.reuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    init(storedAsset: PHAsset? = nil) {
        self.storedAsset = storedAsset
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    #if DEBUG
        init(debugImage: UIImage) {
            self.storedAsset = nil
            self.debugFlyInImage = debugImage
            super.init(nibName: nil, bundle: nil)
            modalPresentationStyle = .pageSheet
        }
    #endif

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        topGradient.colors = [
            .systemBackground,
            .systemBackground.withAlphaComponent(0.0)
        ]
        configureSheet()
        setupInitialAlbums()
        setupUI()
        setupConstraints()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimationSequence()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cancelAllWorkItems()
    }

    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = [.large()]
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    private func setupInitialAlbums() {
        albums = [
            AlbumItem(title: Strings.albumRecents, sfSymbol: "clock.fill", tint: .systemGray3, showBadge: false),
            AlbumItem(title: Strings.albumScreenshots, sfSymbol: "camera.viewfinder", tint: .systemGray3, showBadge: false),
            AlbumItem(title: Strings.albumVideos, sfSymbol: "video.fill", tint: .systemGray3, showBadge: false),
            AlbumItem(title: Strings.albumFavorites, sfSymbol: "heart.fill", tint: .systemGray3, showBadge: true),

            AlbumItem(title: Strings.albumSelfies, sfSymbol: "person.crop.square", tint: .systemGray3, showBadge: false)
        ]
    }

    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(topGradient)
        view.addSubview(logoImageView)
    }

    private func setupConstraints() {
        let screenWidth = UIScreen.main.bounds.width
        let cellSize = (screenWidth - 24 - 24 - 16) / 2
        let collectionHeight = 24 + (cellSize * 3) + (20 * 2) + 24

        let topAreaGuide = UILayoutGuide()
        view.addLayoutGuide(topAreaGuide)

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -40),
            collectionView.heightAnchor.constraint(equalToConstant: collectionHeight),

            topAreaGuide.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topAreaGuide.bottomAnchor.constraint(equalTo: collectionView.topAnchor),
            topAreaGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topAreaGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            topGradient.topAnchor.constraint(equalTo: collectionView.topAnchor),
            topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topGradient.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5),

            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 80),
            logoImageView.heightAnchor.constraint(equalToConstant: 80)
        ])

        let isSmallScreen = UIScreen.main.bounds.height <= 667
        if isSmallScreen {
            logoImageView.centerYAnchor.constraint(equalTo: collectionView.topAnchor).isActive = true
        } else {
            logoImageView.centerYAnchor.constraint(equalTo: topAreaGuide.centerYAnchor).isActive = true
        }
    }

    private func startAnimationSequence() {
        let delay = hasContent ? WithContentTimings.cellInsertDelay : WithoutContentTimings.cellInsertDelay
        let popWork = DispatchWorkItem { [weak self] in
            self?.insertWillBeStoredCell()
        }
        self.popWorkItem = popWork
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: popWork)
    }

    private func insertWillBeStoredCell() {
        let willBeStoredAlbum = AlbumItem(
            title: Strings.albumWillBeStored,
            sfSymbol: "archivebox.fill",
            tint: ThemeManager.Colors.statusYellow,
            showBadge: false
        )
        albums.append(willBeStoredAlbum)

        collectionView.reloadData()
        collectionView.layoutIfNeeded()

        let indexPath = IndexPath(item: 5, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) else {
            scheduleFlyInOrDismiss()
            return
        }
        cell.alpha = 0

        let cellFrame = cell.convert(cell.bounds, to: view)
        let overlay = FakeAlbumCell(frame: cellFrame)
        overlay.configure(
            title: Strings.albumWillBeStored,
            sfSymbol: "archivebox.fill",
            tint: ThemeManager.Colors.statusYellow
        )
        overlay.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        overlay.alpha = 0
        view.addSubview(overlay)

        let duration = hasContent ? WithContentTimings.cellPopDuration : WithoutContentTimings.cellPopDuration
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.8,
            options: [],
            animations: {
                overlay.transform = .identity
                overlay.alpha = 1
            },
            completion: { [weak self] _ in
                cell.alpha = 1
                overlay.removeFromSuperview()
                self?.scheduleFlyInOrDismiss()
            }
        )
    }

    private func scheduleFlyInOrDismiss() {
        #if DEBUG
            if let debugImage = debugFlyInImage {
                let flyWork = DispatchWorkItem { [weak self] in
                    self?.flyDebugImageIntoCell(image: debugImage)
                }
                self.flyInWorkItem = flyWork
                DispatchQueue.main.asyncAfter(deadline: .now() + WithContentTimings.flyInDelay, execute: flyWork)
                return
            }
        #endif

        guard let storedAsset else {
            scheduleDismiss()
            return
        }

        let flyWork = DispatchWorkItem { [weak self] in
            self?.flyPhotoIntoCell(asset: storedAsset)
        }
        self.flyInWorkItem = flyWork
        DispatchQueue.main.asyncAfter(deadline: .now() + WithContentTimings.flyInDelay, execute: flyWork)
    }

    private func flyPhotoIntoCell(asset: PHAsset) {
        let targetIndexPath = IndexPath(item: 5, section: 0)
        guard let cell = collectionView.cellForItem(at: targetIndexPath) as? FakeAlbumCell else {
            scheduleDismiss()
            return
        }

        let targetFrame = cell.convert(cell.bounds, to: view)
        let imageSize = CGSize(width: targetFrame.width * 2, height: targetFrame.height * 2)

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: imageSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let self, let image, !self.hasStartedFlyIn else {
                if self?.hasStartedFlyIn == false {
                    self?.scheduleDismiss()
                }
                return
            }
            self.hasStartedFlyIn = true
            self.animateFlyIn(image: image, targetCell: cell, targetFrame: targetFrame)
        }
    }

    private func animateFlyIn(image: UIImage, targetCell: FakeAlbumCell, targetFrame: CGRect) {
        let flyingView = UIImageView(image: image)
        flyingView.contentMode = .scaleAspectFill
        flyingView.clipsToBounds = true
        flyingView.layer.cornerRadius = 12

        let startWidth = targetFrame.width
        let startHeight = targetFrame.height
        let startX = view.bounds.midX - startWidth / 2
        flyingView.frame = CGRect(x: startX, y: -startHeight, width: startWidth, height: startHeight)
        view.addSubview(flyingView)

        UIView.animate(
            withDuration: WithContentTimings.slideDuration,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.3,
            options: [],
            animations: {
                flyingView.frame = targetFrame
            },
            completion: { [weak self] _ in
                UIView.animate(
                    withDuration: WithContentTimings.popUpDuration,
                    delay: WithContentTimings.popUpDelay,
                    options: .curveEaseOut,
                    animations: {
                        flyingView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
                    },
                    completion: { _ in
                        UIView.animate(
                            withDuration: WithContentTimings.shrinkDuration,
                            delay: 0,
                            options: .curveEaseIn,
                            animations: {
                                flyingView.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
                                flyingView.alpha = 0
                            },
                            completion: { _ in
                                flyingView.removeFromSuperview()
                                self?.scheduleDismiss()
                            }
                        )
                    }
                )
            }
        )
    }

    #if DEBUG
        private func flyDebugImageIntoCell(image: UIImage) {
            let targetIndexPath = IndexPath(item: 5, section: 0)
            guard let cell = collectionView.cellForItem(at: targetIndexPath) as? FakeAlbumCell else {
                scheduleDismiss()
                return
            }
            let targetFrame = cell.convert(cell.bounds, to: view)
            animateFlyIn(image: image, targetCell: cell, targetFrame: targetFrame)
        }
    #endif

    private func scheduleDismiss() {
        let delay = hasContent ? WithContentTimings.dismissDelay : WithoutContentTimings.dismissDelay
        let work = DispatchWorkItem { [weak self] in
            self?.dismiss(animated: true)
        }
        self.dismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelAllWorkItems() {
        popWorkItem?.cancel()
        flyInWorkItem?.cancel()
        dismissWorkItem?.cancel()
    }
}

extension StoreTutorialSheetViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        albums.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: FakeAlbumCell.reuseIdentifier, for: indexPath)
            as! FakeAlbumCell
        let album = albums[indexPath.item]
        cell.configure(title: album.title, sfSymbol: album.sfSymbol, tint: album.tint, showBadge: album.showBadge)
        return cell
    }
}


extension StoreTutorialSheetViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let width = (collectionView.bounds.width - 24 - 24 - 16) / 2
        let height = width
        return CGSize(width: width, height: height)
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct StoreTutorialSheetPreview: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> StoreTutorialSheetViewController {
            StoreTutorialSheetViewController(storedAsset: nil)
        }

        func updateUIViewController(_ uiViewController: StoreTutorialSheetViewController, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Without Content (Settings)") {
        StoreTutorialSheetPreview()
    }

    @available(iOS 17.0, *)
    private struct StoreTutorialSheetWithContentPreview: UIViewControllerRepresentable {
        func makeUIViewController(context: Context) -> StoreTutorialSheetViewController {
            let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .medium)
            let image = UIImage(systemName: "photo.fill", withConfiguration: config)?
                .withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
            return StoreTutorialSheetViewController(debugImage: image ?? UIImage())
        }

        func updateUIViewController(_ uiViewController: StoreTutorialSheetViewController, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("With Content (Swipe)") {
        StoreTutorialSheetWithContentPreview()
    }
#endif

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

private enum Layout {
    static let itemCount = 6
    static let columnChoices = [2, 3]
    static let sectionInset: CGFloat = 24
    static let interitemSpacing: CGFloat = 16
    static let lineSpacing: CGFloat = 20
    static let bottomSpacing: CGFloat = 40
    static let compactBottomSpacing: CGFloat = 16
    static let logoTopClearance: CGFloat = 24
    static let logoSize: CGFloat = 80
    static let logoClearance: CGFloat = 12
    static let gradientViewRatio: CGFloat = 0.5
    static let gradientGridRatio: CGFloat = 0.6
}

final class StoreTutorialSheetViewController: UIViewController {

    private struct AlbumItem {
        let title: String
        let sfSymbol: String
        let tint: UIColor
        let showBadge: Bool
    }

    /// Everything size-dependent, recomputed on each layout pass and applied only when it changes.
    private struct GridGeometry: Equatable {
        var cellSize: CGFloat
        var columns: Int
        var leadingInset: CGFloat
        var columnSpacing: CGFloat
        var collectionTop: CGFloat
        var collectionHeight: CGFloat
        var logoCenterY: CGFloat
        var isHorizontalSplit: Bool
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

    private let gridLayout = AlbumGridLayout()
    private var appliedGeometry: GridGeometry?
    private var appliedGradientTraitsKey: String?
    private var isLayoutFrozen = false
    private var collectionTopConstraint: NSLayoutConstraint?
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var logoCenterYConstraint: NSLayoutConstraint?
    private var gradientViewHeightConstraint: NSLayoutConstraint?
    private var gradientGridHeightConstraint: NSLayoutConstraint?

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.isUserInteractionEnabled = false
        collectionView.dataSource = self
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
        configureSheet()
        setupInitialAlbums()
        setupUI()
        setupConstraint()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitUserInterfaceLevel.self]) {
                (self: StoreTutorialSheetViewController, _) in
                self.updateGradientColors()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateGradientColors()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateGradientColors()
        updateGridLayout()
    }

    /// Resolves the fade against the sheet's own traits: a sheet is elevated, so in dark mode its
    /// background is gray, and an unresolved `.systemBackground` would draw a black band.
    private func updateGradientColors() {
        let traits = traitCollection
        let key = "\(traits.userInterfaceStyle.rawValue)-\(traits.userInterfaceLevel.rawValue)"
        guard key != appliedGradientTraitsKey else { return }
        appliedGradientTraitsKey = key
        let background = UIColor.systemBackground.resolvedColor(with: traits)
        topGradient.colors = [background, background.withAlphaComponent(0.0)]
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnimationSequence()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isLayoutFrozen = false
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // While the sheet slides away the fold moves through it, which would
        // briefly switch the grid to another layout; keep the one on screen.
        isLayoutFrozen = true
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

    private func setupConstraint() {
        let collectionTop = collectionView.topAnchor.constraint(equalTo: view.topAnchor)
        let collectionHeight = collectionView.heightAnchor.constraint(equalToConstant: 0)
        let logoCenterY = logoImageView.centerYAnchor.constraint(equalTo: view.topAnchor)
        let gradientViewHeight = topGradient.heightAnchor.constraint(
            equalTo: view.heightAnchor, multiplier: Layout.gradientViewRatio)
        gradientGridHeightConstraint = topGradient.heightAnchor.constraint(
            equalTo: collectionView.heightAnchor, multiplier: Layout.gradientGridRatio)
        collectionTopConstraint = collectionTop
        collectionHeightConstraint = collectionHeight
        logoCenterYConstraint = logoCenterY
        gradientViewHeightConstraint = gradientViewHeight

        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            collectionTop,
            collectionHeight,

            topGradient.topAnchor.constraint(equalTo: collectionView.topAnchor),
            topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientViewHeight,

            logoImageView.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            logoCenterY,
            logoImageView.widthAnchor.constraint(equalToConstant: Layout.logoSize),
            logoImageView.heightAnchor.constraint(equalToConstant: Layout.logoSize)
        ])
    }

    // MARK: - Grid Layout

    /// Sizes the album grid to fit both the sheet's width and its height, and splits it
    /// at the iPhone Duo's fold. On iPhones the width-based 2-column grid already fits,
    /// so the result there matches the original design.
    private func updateGridLayout() {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        guard !isLayoutFrozen || appliedGeometry == nil else { return }

        let insets = view.safeAreaInsets
        let gridWidth = bounds.width - insets.left - insets.right
        let isFolded = FoldRegion.activeFold(in: view) != nil
        let fold = FoldRegion.splittingFold(in: view)

        let geometry: GridGeometry
        if let fold, fold.height > fold.width {
            geometry = fittedGeometry(viewHeight: bounds.height, safeTop: insets.top) { gridBottom in
                self.verticalSplitGeometry(
                    fold: fold, isFolded: isFolded, gridWidth: gridWidth, gridBottom: gridBottom, insets: insets)
            }
        } else if let fold, traitCollection.horizontalSizeClass == .regular {
            geometry = horizontalSplitGeometry(
                fold: fold, isFolded: isFolded, gridWidth: gridWidth,
                gridBottom: bounds.height - Layout.bottomSpacing, safeTop: insets.top)
        } else {
            geometry = fittedGeometry(viewHeight: bounds.height, safeTop: insets.top) { gridBottom in
                self.singleGeometry(gridWidth: gridWidth, gridBottom: gridBottom, safeTop: insets.top)
            }
        }

        guard geometry != appliedGeometry else { return }
        appliedGeometry = geometry

        collectionTopConstraint?.constant = geometry.collectionTop
        collectionHeightConstraint?.constant = geometry.collectionHeight
        logoCenterYConstraint?.constant = geometry.logoCenterY
        gradientViewHeightConstraint?.isActive = !geometry.isHorizontalSplit
        gradientGridHeightConstraint?.isActive = geometry.isHorizontalSplit

        gridLayout.cellSize = geometry.cellSize
        gridLayout.columns = geometry.columns
        gridLayout.leadingInset = geometry.leadingInset
        gridLayout.columnSpacing = geometry.columnSpacing
        gridLayout.invalidateLayout()
    }

    /// One column of content: the logo above a bottom-anchored grid.
    private func singleGeometry(gridWidth: CGFloat, gridBottom: CGFloat, safeTop: CGFloat) -> GridGeometry {
        let availableHeight = gridBottom - safeTop - minimumLogoReserve
        let (columns, cellSize) = bestFit(width: gridWidth, height: availableHeight)
        let height = gridHeight(columns: columns, cellSize: cellSize)
        let top = gridBottom - height
        return GridGeometry(
            cellSize: cellSize,
            columns: columns,
            leadingInset: centeredInset(width: gridWidth, columns: columns, cellSize: cellSize),
            columnSpacing: Layout.interitemSpacing,
            collectionTop: top,
            collectionHeight: height,
            logoCenterY: logoCenterY(safeTop: safeTop, gridTop: top),
            isHorizontalSplit: false
        )
    }

    /// Upright inner display: the logo on the raised half, the grid on the base.
    /// The gap is centered on the fold line while open and clears the fold region while folded.
    private func horizontalSplitGeometry(
        fold: CGRect, isFolded: Bool, gridWidth: CGFloat, gridBottom: CGFloat, safeTop: CGFloat
    ) -> GridGeometry {
        let halfGap = GeneralConstants.Spacer.foldGap / 2
        let raisedBottom = isFolded ? fold.minY : fold.midY - halfGap
        let baseTop = isFolded ? fold.maxY : fold.midY + halfGap
        let (columns, cellSize) = bestFit(width: gridWidth, height: gridBottom - baseTop)
        let height = gridHeight(columns: columns, cellSize: cellSize)
        return GridGeometry(
            cellSize: cellSize,
            columns: columns,
            leadingInset: centeredInset(width: gridWidth, columns: columns, cellSize: cellSize),
            columnSpacing: Layout.interitemSpacing,
            collectionTop: gridBottom - height,
            collectionHeight: height,
            logoCenterY: (safeTop + raisedBottom) / 2,
            isHorizontalSplit: true
        )
    }

    /// Inner display held sideways: two columns, one on each side of the fold,
    /// so no tile sits on it.
    private func verticalSplitGeometry(
        fold: CGRect, isFolded: Bool, gridWidth: CGFloat, gridBottom: CGFloat, insets: UIEdgeInsets
    ) -> GridGeometry {
        let columns = 2
        var foldCenter = fold.midX - insets.left
        if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
            foldCenter = gridWidth - foldCenter
        }
        let gap = isFolded ? max(Layout.interitemSpacing, fold.width) : Layout.interitemSpacing
        let leadingRoom = foldCenter - gap / 2 - Layout.sectionInset
        let trailingRoom = gridWidth - foldCenter - gap / 2 - Layout.sectionInset
        let availableHeight = gridBottom - insets.top - minimumLogoReserve
        let cellSize = max(0, min(leadingRoom, trailingRoom, heightFit(columns: columns, height: availableHeight)))
        let height = gridHeight(columns: columns, cellSize: cellSize)
        let top = gridBottom - height
        return GridGeometry(
            cellSize: cellSize,
            columns: columns,
            leadingInset: foldCenter - gap / 2 - cellSize,
            columnSpacing: gap,
            collectionTop: top,
            collectionHeight: height,
            logoCenterY: logoCenterY(safeTop: insets.top, gridTop: top),
            isHorizontalSplit: false
        )
    }

    /// The column count with the largest square tile that fits; ties keep 2 columns.
    private func bestFit(width: CGFloat, height: CGFloat) -> (columns: Int, cellSize: CGFloat) {
        var best = (columns: Layout.columnChoices[0], cellSize: -CGFloat.greatestFiniteMagnitude)
        for columns in Layout.columnChoices {
            let widthFit = (width - 2 * Layout.sectionInset - CGFloat(columns - 1) * Layout.interitemSpacing)
                / CGFloat(columns)
            let cellSize = min(widthFit, heightFit(columns: columns, height: height))
            if cellSize > best.cellSize {
                best = (columns, cellSize)
            }
        }
        return (best.columns, max(0, best.cellSize))
    }

    private func rows(columns: Int) -> Int {
        (Layout.itemCount + columns - 1) / columns
    }

    private func heightFit(columns: Int, height: CGFloat) -> CGFloat {
        let rows = rows(columns: columns)
        return (height - 2 * Layout.sectionInset - CGFloat(rows - 1) * Layout.lineSpacing) / CGFloat(rows)
    }

    private func gridHeight(columns: Int, cellSize: CGFloat) -> CGFloat {
        let rows = rows(columns: columns)
        return 2 * Layout.sectionInset + CGFloat(rows) * cellSize + CGFloat(rows - 1) * Layout.lineSpacing
    }

    private func centeredInset(width: CGFloat, columns: Int, cellSize: CGFloat) -> CGFloat {
        (width - CGFloat(columns) * cellSize - CGFloat(columns - 1) * Layout.interitemSpacing) / 2
    }

    /// Lays out with the standard bottom space; when that leaves the logo short of room
    /// (a short sheet: the cover display, Split View), gives the bottom space to the grid instead.
    private func fittedGeometry(
        viewHeight: CGFloat, safeTop: CGFloat, make: (CGFloat) -> GridGeometry
    ) -> GridGeometry {
        let roomy = make(viewHeight - Layout.bottomSpacing)
        guard roomy.collectionTop - safeTop < roomyLogoSpace else { return roomy }
        return make(viewHeight - Layout.compactBottomSpacing)
    }

    /// Room above the grid's frame in which the logo is simply centered (the iPhone look).
    private var roomyLogoSpace: CGFloat {
        Layout.logoTopClearance + Layout.logoSize + Layout.logoClearance
    }

    /// The least room above the grid's frame that keeps the logo clear of the grabber above it
    /// and the first row below it, sharing the grid's top inset.
    private var minimumLogoReserve: CGFloat {
        Layout.logoTopClearance + Layout.logoSize + Layout.logoClearance - Layout.sectionInset
    }

    /// Centered in the space above the grid when it fits, otherwise between the grabber's
    /// clearance and the first row, so it never overlaps the tiles or crowds the grabber.
    private func logoCenterY(safeTop: CGFloat, gridTop: CGFloat) -> CGFloat {
        let space = gridTop - safeTop
        if space >= roomyLogoSpace {
            return safeTop + space / 2
        }
        let top = safeTop + Layout.logoTopClearance
        let bottom = gridTop + Layout.sectionInset - Layout.logoClearance
        return (top + bottom) / 2
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
        flyingView.layer.cornerCurve = .continuous

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

// MARK: - AlbumGridLayout

/// Places the album tiles at fixed grid positions: square tiles, a leading inset and a
/// column spacing the sheet computes, so a partly filled last row stays left-aligned
/// and the new tile pops in exactly where it ends up.
private final class AlbumGridLayout: UICollectionViewLayout {
    var cellSize: CGFloat = 0
    var columns = 2
    var leadingInset: CGFloat = Layout.sectionInset
    var columnSpacing: CGFloat = Layout.interitemSpacing

    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []

    override var flipsHorizontallyInOppositeLayoutDirection: Bool { true }

    override func prepare() {
        super.prepare()
        cachedAttributes = []
        guard let collectionView, collectionView.numberOfSections > 0, cellSize > 0, columns > 0 else { return }
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: 0))
            let column = item % columns
            let row = item / columns
            attributes.frame = CGRect(
                x: leadingInset + CGFloat(column) * (cellSize + columnSpacing),
                y: Layout.sectionInset + CGFloat(row) * (cellSize + Layout.lineSpacing),
                width: cellSize,
                height: cellSize
            )
            cachedAttributes.append(attributes)
        }
    }

    override var collectionViewContentSize: CGSize {
        collectionView?.bounds.size ?? .zero
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.size != collectionView?.bounds.size
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

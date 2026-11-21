//
//  SimilarSetCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let undo = NSLocalizedString("similarGroup.undoAction", comment: "Undo action button")
    static let confirm = NSLocalizedString("similarGroup.confirm", comment: "Confirm button")
    static let store = NSLocalizedString("similarGroup.store", comment: "Store state label")
    static let storeDone = NSLocalizedString("similarGroup.storeDone", comment: "Store button while store mode is on")
    static let notConfirmed = NSLocalizedString("similarGroup.notConfirmed", comment: "VoiceOver: the set isn't confirmed yet")
    static let confirmedState = NSLocalizedString("similarGroup.confirmedState", comment: "VoiceOver: the set is confirmed")
    static let unknownSize = "–"
    static func setTitle(index: Int) -> String {
        String(format: NSLocalizedString("similarGroup.setTitle", comment: "Set title with number, e.g. 'Set #1'"), index + 1)
    }
    static func subtitle(count: Int, size: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarGroup.subtitle", comment: "A set's photo count and size, e.g. '4 photos · 14.2 MB'"),
            count, size)
    }
    static func confirmedSubtitle(kept: Int, binned: Int, stored: Int) -> String {
        var parts: [String] = []
        if kept > 0 {
            parts.append(String.localizedStringWithFormat(
                NSLocalizedString("similarGroup.keptPart", comment: "Confirmed set: how many were kept, e.g. 'Kept 1'"), kept))
        }
        if binned > 0 {
            parts.append(String.localizedStringWithFormat(
                NSLocalizedString("similarGroup.binPart", comment: "Confirmed set: how many went to the bin, e.g. '3 to the bin'"), binned))
        }
        if stored > 0 {
            parts.append(String.localizedStringWithFormat(
                NSLocalizedString("similarGroup.storedPart", comment: "Confirmed set: how many were stored, e.g. '1 stored'"), stored))
        }
        return parts.joined(separator: " · ")
    }
    static func countsAccessibility(kept: Int, deleted: Int, stored: Int) -> String {
        var parts: [String] = []
        if kept > 0 {
            parts.append(String.localizedStringWithFormat(
                NSLocalizedString("similarPhotos.keepCount", comment: "Keep photo count, e.g. 'Keep 3 photos'"), kept))
        }
        if deleted > 0 {
            parts.append(String.localizedStringWithFormat(
                NSLocalizedString("similarPhotos.deleteCount", comment: "Delete photo count, e.g. 'Delete 2 photos'"), deleted))
        }
        if stored > 0 {
            parts.append(String.localizedStringWithFormat(
                NSLocalizedString("similarPhotos.storeCount", comment: "Store photo count, e.g. 'Store 1 photo'"), stored))
        }
        return parts.joined(separator: ", ")
    }
}

/// One similar set as a card (board "Similar photos · A"): a header (the stamp, "Set N" over the
/// photo count and size, Store), the photos in a sideways row sized from the card's own width,
/// and a footer with the counts and Confirm. Confirmed, it collapses into one row: the stamp,
/// what happened to the photos and Undo. The months' list cell and the Duo's upright spotlight
/// both use it.
final class SimilarSetCardView: UIView {

    private enum Layout {
        static let padding = GeneralConstants.EdgePadding.cardInner
        static let stampSize = CGSize(width: 12, height: 32)
        static let stampCapsuleWidth: CGFloat = 10
        /// Clears the stamp's check, which is wider than its capsule
        static let stampToText: CGFloat = 14
        static let headerHeight: CGFloat = 36
        static let confirmedRowHeight = GeneralConstants.ButtonSize.medium
        static let confirmedVerticalPadding = GeneralConstants.EdgePadding.small
        static let rowSpacing: CGFloat = 14
        static let thumbnailSpacing: CGFloat = 8
        static let thumbnailRange: ClosedRange<CGFloat> = 60...120
        /// A card that fills a taller space never shrinks its photos under this
        static let minimumFilledThumbnail: CGFloat = 44
        static let buttonHeight: CGFloat = 36
        static let buttonInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        static let buttonFontSize: CGFloat = 14
        static let buttonIconSize: CGFloat = 12
        static let chipSpacing: CGFloat = 12
        static let chipIconToCount: CGFloat = 4
        static let chipFontSize: CGFloat = 13
        static let chipIconSize: CGFloat = 11
    }

    // MARK: - Callbacks

    var onConfirm: (() -> Void)?
    var onUndo: (() -> Void)?
    /// A photo's mark changed; the host keeps the states
    var onStatesChange: (([String: SimilarPhotoState]) -> Void)?
    /// The user touched this card's photos or its Store button (one store mode at a time)
    var onInteraction: (() -> Void)?

    /// True where the card is given more height than it needs (the Duo's upright spotlight):
    /// the photos center in the extra room and shrink when the height is short.
    var fillsHeight = false {
        didSet { if fillsHeight != oldValue { setNeedsLayout() } }
    }

    private(set) var isConfirmed = false
    private(set) var signature: String?

    // MARK: - Views

    private let stampView: ReviewStampView = {
        let view = ReviewStampView()
        view.capsuleWidth = Layout.stampCapsuleWidth
        view.status = .notStarted
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: 17, weight: .semibold)
        label.textColor = .textPrimary
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 2
        stack.isAccessibilityElement = true
        stack.accessibilityTraits = .header
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var storeButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(handleStoreToggle), for: .touchUpInside)
        return button
    }()

    private lazy var undoButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = Strings.undo
        config.baseForegroundColor = .label
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .semibold)
            return outgoing
        }
        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleUndo), for: .touchUpInside)
        return button
    }()

    private let flowLayout: UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = Layout.thumbnailSpacing
        layout.minimumLineSpacing = Layout.thumbnailSpacing
        layout.sectionInset = UIEdgeInsets(top: 0, left: Layout.padding, bottom: 0, right: Layout.padding)
        return layout
    }()

    private lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(PhotoGridCell.self, forCellWithReuseIdentifier: PhotoGridCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private let footerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let chipsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.chipSpacing
        stack.alignment = .center
        stack.isAccessibilityElement = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let keepChip = SimilarSetCardView.makeChip(for: .keep)
    private let deleteChip = SimilarSetCardView.makeChip(for: .delete)
    private let storeChip = SimilarSetCardView.makeChip(for: .store)

    private lazy var confirmButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        return button
    }()

    /// The room above and under the photos; equal, so the photos center when the card is taller
    private let photosTopGuide = UILayoutGuide()
    private let photosBottomGuide = UILayoutGuide()

    // MARK: - State

    private var assets: [PHAsset] = []
    private var bestAssetId: String?
    private var states: [String: SimilarPhotoState] = [:]
    private var sizes: [String: Int64]?
    private var setIndex = 0
    private var isStoreMode = false
    private var appliedThumbnailSide: CGFloat = 0

    private var headerTopConstraint: NSLayoutConstraint?
    private var headerHeightConstraint: NSLayoutConstraint?
    private var collectionHeightConstraint: NSLayoutConstraint?
    private var expandedConstraints: [NSLayoutConstraint] = []
    private var confirmedConstraints: [NSLayoutConstraint] = []

    // Preview overlay
    private var previewOverlay: UIView?
    private var previewImageView: UIImageView?
    private var previewRequestID: PHImageRequestID?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
        setupLongPressGesture()
        applyButtonStyles()
        applyConfirmedAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        // The photos and the footer slide out under the card's edge when it collapses
        clipsToBounds = true

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        [keepChip, deleteChip, storeChip].forEach { chipsStack.addArrangedSubview($0.view) }

        addSubview(headerView)
        headerView.addSubview(stampView)
        headerView.addSubview(textStack)
        headerView.addSubview(storeButton)
        headerView.addSubview(undoButton)
        addSubview(collectionView)
        addSubview(footerView)
        footerView.addSubview(chipsStack)
        footerView.addSubview(confirmButton)
        addLayoutGuide(photosTopGuide)
        addLayoutGuide(photosBottomGuide)
    }

    private func setupConstraint() {
        let headerTop = headerView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.padding)
        let headerHeight = headerView.heightAnchor.constraint(equalToConstant: Layout.headerHeight)
        let collectionHeight = collectionView.heightAnchor.constraint(
            equalToConstant: Layout.thumbnailRange.lowerBound)
        headerTopConstraint = headerTop
        headerHeightConstraint = headerHeight
        collectionHeightConstraint = collectionHeight

        // The photos hug the header and the footer unless the card is given more height
        let hugTop = photosTopGuide.heightAnchor.constraint(equalToConstant: Layout.rowSpacing)
        hugTop.priority = .defaultLow

        NSLayoutConstraint.activate([
            headerTop,
            headerHeight,
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),

            stampView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            stampView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            stampView.widthAnchor.constraint(equalToConstant: Layout.stampSize.width),
            stampView.heightAnchor.constraint(equalToConstant: Layout.stampSize.height),

            textStack.leadingAnchor.constraint(equalTo: stampView.trailingAnchor, constant: Layout.stampToText),
            textStack.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: storeButton.leadingAnchor, constant: -8),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: undoButton.leadingAnchor, constant: -8),

            storeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            storeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            storeButton.heightAnchor.constraint(equalToConstant: Layout.buttonHeight),

            undoButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            undoButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            undoButton.heightAnchor.constraint(equalToConstant: Layout.confirmedRowHeight),

            photosTopGuide.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            photosTopGuide.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.rowSpacing),
            photosTopGuide.heightAnchor.constraint(equalTo: photosBottomGuide.heightAnchor),
            hugTop,

            collectionView.topAnchor.constraint(equalTo: photosTopGuide.bottomAnchor),
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionHeight,

            photosBottomGuide.topAnchor.constraint(equalTo: collectionView.bottomAnchor),
            footerView.topAnchor.constraint(equalTo: photosBottomGuide.bottomAnchor),
            footerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            footerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),
            footerView.heightAnchor.constraint(equalToConstant: Layout.buttonHeight),

            chipsStack.leadingAnchor.constraint(equalTo: footerView.leadingAnchor),
            chipsStack.centerYAnchor.constraint(equalTo: footerView.centerYAnchor),
            chipsStack.trailingAnchor.constraint(lessThanOrEqualTo: confirmButton.leadingAnchor, constant: -8),

            confirmButton.trailingAnchor.constraint(equalTo: footerView.trailingAnchor),
            confirmButton.topAnchor.constraint(equalTo: footerView.topAnchor),
            confirmButton.bottomAnchor.constraint(equalTo: footerView.bottomAnchor)
        ])

        expandedConstraints = [
            footerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.padding)
        ]
        confirmedConstraints = [
            headerView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.confirmedVerticalPadding)
        ]
        NSLayoutConstraint.activate(expandedConstraints)
    }

    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        collectionView.addGestureRecognizer(longPress)
    }

    /// A count chip: the state's icon in its color and a count. The help sheet's sample set reuses it.
    static func makeChip(for state: SimilarPhotoState) -> (view: UIStackView, label: UILabel) {
        let icon = UIImageView(
            image: UIImage(
                systemName: state.chipIcon,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.chipIconSize, weight: .bold)))
        icon.tintColor = state.color
        icon.contentMode = .center
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: Layout.chipFontSize, weight: .semibold)
        label.textColor = .secondaryLabel

        let stack = UIStackView(arrangedSubviews: [icon, label])
        stack.axis = .horizontal
        stack.spacing = Layout.chipIconToCount
        stack.alignment = .center
        return (stack, label)
    }

    // MARK: - Configuration

    /// Shows a set. `states` is the host's record of each photo's mark; `sizes` its per-photo
    /// bytes, nil until they're known. Configuring the set the card already shows keeps its
    /// photos' scroll position and store mode.
    func configure(
        index: Int, signature: String, assets: [PHAsset], bestAssetId: String?,
        states: [String: SimilarPhotoState], sizes: [String: Int64]?, isConfirmed: Bool
    ) {
        let isSameSet = signature == self.signature
        self.signature = signature
        self.setIndex = index
        self.bestAssetId = bestAssetId
        self.states = states
        self.sizes = sizes

        if !isSameSet {
            var ordered = assets
            if let bestAssetId,
               let bestIndex = ordered.firstIndex(where: { $0.localIdentifier == bestAssetId }), bestIndex != 0 {
                ordered.insert(ordered.remove(at: bestIndex), at: 0)
            }
            self.assets = ordered
            if isStoreMode {
                isStoreMode = false
                applyButtonStyles()
            }
            collectionView.setContentOffset(.zero, animated: false)
            collectionView.reloadData()
        } else {
            refreshVisiblePhotoStates()
        }

        titleLabel.text = Strings.setTitle(index: index)
        if isConfirmed != self.isConfirmed {
            self.isConfirmed = isConfirmed
            applyConfirmedAppearance()
        }
        updateTexts()
    }

    func updateSizes(_ sizes: [String: Int64]?) {
        self.sizes = sizes
        updateTexts()
    }

    /// Collapses into the confirmed row or expands back. The host animates the layout change.
    func setConfirmed(_ isConfirmed: Bool) {
        guard isConfirmed != self.isConfirmed else { return }
        self.isConfirmed = isConfirmed
        if isConfirmed { exitStoreModeIfNeeded() }
        applyConfirmedAppearance()
        updateTexts()
    }

    func exitStoreModeIfNeeded() {
        guard isStoreMode else { return }
        exitStoreMode()
    }

    /// The photos' side for a card this wide: four across (three when four would be under
    /// 60pt), 60…120.
    static func thumbnailSide(forCardWidth width: CGFloat) -> CGFloat {
        let available = width - 2 * Layout.padding
        guard available > 0 else { return Layout.thumbnailRange.lowerBound }
        var side = (available - 3 * Layout.thumbnailSpacing) / 4
        if side < Layout.thumbnailRange.lowerBound {
            side = (available - 2 * Layout.thumbnailSpacing) / 3
        }
        return floor(min(max(side, Layout.thumbnailRange.lowerBound), Layout.thumbnailRange.upperBound))
    }

    /// Sizes the photos for a width before the card is measured (a self-sizing cell asks for
    /// its height before it's laid out).
    func prepareLayout(forWidth width: CGFloat) {
        var side = Self.thumbnailSide(forCardWidth: width)
        if fillsHeight, bounds.height > 0, !isConfirmed {
            let chrome = 2 * Layout.padding + Layout.headerHeight + 2 * Layout.rowSpacing + Layout.buttonHeight
            side = max(Layout.minimumFilledThumbnail, min(side, floor(bounds.height - chrome)))
        }
        guard side != appliedThumbnailSide else { return }
        appliedThumbnailSide = side
        flowLayout.itemSize = CGSize(width: side, height: side)
        collectionHeightConstraint?.constant = side
        flowLayout.invalidateLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        prepareLayout(forWidth: bounds.width)
    }

    // MARK: - Appearance

    private func applyConfirmedAppearance() {
        NSLayoutConstraint.deactivate(isConfirmed ? expandedConstraints : confirmedConstraints)
        headerTopConstraint?.constant = isConfirmed ? Layout.confirmedVerticalPadding : Layout.padding
        headerHeightConstraint?.constant = isConfirmed ? Layout.confirmedRowHeight : Layout.headerHeight
        NSLayoutConstraint.activate(isConfirmed ? confirmedConstraints : expandedConstraints)

        stampView.status = isConfirmed ? .done : .notStarted
        let expandedAlpha: CGFloat = isConfirmed ? 0 : 1
        collectionView.alpha = expandedAlpha
        footerView.alpha = expandedAlpha
        // Hidden, not faded: a DynamicGlassButton resets its own alpha when its configuration updates
        storeButton.isHidden = isConfirmed
        undoButton.alpha = isConfirmed ? 1 : 0
        collectionView.isUserInteractionEnabled = !isConfirmed
        footerView.isUserInteractionEnabled = !isConfirmed
        storeButton.isUserInteractionEnabled = !isConfirmed
        undoButton.isUserInteractionEnabled = isConfirmed

        accessibilityElements = isConfirmed
            ? [textStack, undoButton]
            : [textStack, storeButton, collectionView, chipsStack, confirmButton]
    }

    private func applyButtonStyles() {
        let icon = UIImage(
            systemName: "archivebox.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.buttonIconSize, weight: .semibold))?
            .withTintColor(ThemeManager.Colors.statusYellow, renderingMode: .alwaysOriginal)
        storeButton.configure(
            title: isStoreMode ? Strings.storeDone : Strings.store,
            image: icon,
            style: .regular,
            backgroundColor: .systemGray5,
            foregroundColor: .label,
            fontSize: Layout.buttonFontSize,
            contentInsets: Layout.buttonInsets)
        confirmButton.configure(
            title: Strings.confirm,
            style: .regular,
            backgroundColor: .systemGray5,
            foregroundColor: .label,
            fontSize: Layout.buttonFontSize,
            contentInsets: Layout.buttonInsets)
    }

    private func counts() -> (kept: Int, deleted: Int, stored: Int) {
        var kept = 0, deleted = 0, stored = 0
        for asset in assets {
            switch states[asset.localIdentifier] ?? .delete {
            case .keep: kept += 1
            case .delete: deleted += 1
            case .store: stored += 1
            }
        }
        return (kept, deleted, stored)
    }

    private func updateTexts() {
        let (kept, deleted, stored) = counts()

        if isConfirmed {
            subtitleLabel.text = Strings.confirmedSubtitle(kept: kept, binned: deleted, stored: stored)
        } else {
            let sizeText: String
            if let sizes {
                sizeText = assets.reduce(Int64(0)) { $0 + (sizes[$1.localIdentifier] ?? 0) }.formattedBytes()
            } else {
                sizeText = Strings.unknownSize
            }
            subtitleLabel.text = Strings.subtitle(count: assets.count, size: sizeText)
        }

        keepChip.label.text = "\(kept)"
        deleteChip.label.text = "\(deleted)"
        storeChip.label.text = "\(stored)"
        keepChip.view.isHidden = kept == 0
        deleteChip.view.isHidden = deleted == 0
        storeChip.view.isHidden = stored == 0
        chipsStack.accessibilityLabel = Strings.countsAccessibility(kept: kept, deleted: deleted, stored: stored)

        textStack.accessibilityLabel = [
            titleLabel.text, subtitleLabel.text, isConfirmed ? Strings.confirmedState : Strings.notConfirmed
        ].compactMap { $0 }.joined(separator: ", ")
    }

    private func refreshVisiblePhotoStates() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item < assets.count,
                  let cell = collectionView.cellForItem(at: indexPath) as? PhotoGridCell else { continue }
            cell.applyState(states[assets[indexPath.item].localIdentifier] ?? .delete)
        }
    }

    // MARK: - Actions

    @objc private func handleConfirm() {
        exitStoreModeIfNeeded()
        onConfirm?()
    }

    @objc private func handleUndo() {
        onUndo?()
    }

    @objc private func handleStoreToggle() {
        if isStoreMode {
            exitStoreMode()
        } else {
            onInteraction?()
            enterStoreMode()
        }
    }

    private func enterStoreMode() {
        isStoreMode = true
        applyButtonStyles()
        for cell in collectionView.visibleCells {
            (cell as? PhotoGridCell)?.startShake()
        }
        HapticFeedbackManager.shared.impact(intensity: .medium)
    }

    private func exitStoreMode() {
        isStoreMode = false
        applyButtonStyles()
        for cell in collectionView.visibleCells {
            (cell as? PhotoGridCell)?.stopShake()
        }
        HapticFeedbackManager.shared.impact(intensity: .light)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            let point = gesture.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: point), indexPath.item < assets.count
            else { return }

            let cell = collectionView.cellForItem(at: indexPath) as? PhotoGridCell
            showPreview(thumbnail: cell?.currentImage, asset: assets[indexPath.item])
            HapticFeedbackManager.shared.impact(intensity: .medium)

        case .ended, .cancelled, .failed:
            dismissPreview()

        default:
            break
        }
    }

    // MARK: - Full-screen preview (long press)

    private func showPreview(thumbnail: UIImage?, asset: PHAsset) {
        // The card's own window, never a global key-window lookup (see CLAUDE.md → Forbidden APIs).
        guard let window = self.window else { return }

        let overlay = UIView(frame: window.bounds)
        overlay.alpha = 0

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blurView.frame = overlay.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(blurView)

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = thumbnail

        overlay.addSubview(imageView)
        let padding: CGFloat = 24
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: padding),
            imageView.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -padding),
            imageView.leadingAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.leadingAnchor, constant: padding),
            imageView.trailingAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.trailingAnchor, constant: -padding)
        ])

        window.addSubview(overlay)
        previewOverlay = overlay
        previewImageView = imageView

        imageView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            overlay.alpha = 1
            imageView.transform = .identity
        }

        previewRequestID = ImageCacheService.shared.loadImage(
            for: asset,
            quality: .full,
            screenSize: window.bounds.size,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
            traitCollection: traitCollection
        ) { [weak self] image, _, _ in
            guard let self, let image else { return }
            DispatchQueue.main.async {
                self.previewImageView?.image = image
            }
        }
    }

    private func dismissPreview() {
        if let requestID = previewRequestID {
            ImageCacheService.shared.cancelRequest(requestID)
            previewRequestID = nil
        }

        guard let overlay = previewOverlay else { return }
        let imageView = previewImageView

        UIView.animate(
            withDuration: 0.2,
            animations: {
                overlay.alpha = 0
                imageView?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        ) { _ in
            overlay.removeFromSuperview()
        }

        previewOverlay = nil
        previewImageView = nil
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate

extension SimilarSetCardView: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        assets.count
    }

    func collectionView(
        _ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: PhotoGridCell.reuseIdentifier, for: indexPath)
            as! PhotoGridCell
        let asset = assets[indexPath.item]
        cell.configure(with: asset)
        cell.applyState(states[asset.localIdentifier] ?? .delete)
        if isStoreMode {
            cell.startShake()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < assets.count else { return }
        onInteraction?()

        let assetId = assets[indexPath.item].localIdentifier
        let currentState = states[assetId] ?? .delete

        if isStoreMode {
            if currentState == .store {
                states[assetId] = assetId == bestAssetId ? .keep : .delete
            } else {
                states[assetId] = .store
            }
        } else {
            switch currentState {
            case .keep: states[assetId] = .delete
            case .delete: states[assetId] = .keep
            case .store: states[assetId] = .delete
            }
        }

        HapticFeedbackManager.shared.selection()
        (collectionView.cellForItem(at: indexPath) as? PhotoGridCell)?.applyState(states[assetId] ?? .delete)
        updateTexts()
        onStatesChange?(states)
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    private struct SimilarSetCardPreview: UIViewRepresentable {
        let isConfirmed: Bool

        func makeUIView(context: Context) -> SimilarSetCardView {
            let card = SimilarSetCardView()
            card.configure(
                index: 2, signature: "preview", assets: [], bestAssetId: nil, states: [:],
                sizes: nil, isConfirmed: isConfirmed)
            return card
        }

        func updateUIView(_ uiView: SimilarSetCardView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Not confirmed") {
        SimilarSetCardPreview(isConfirmed: false)
            .frame(height: 230)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    @available(iOS 17.0, *)
    #Preview("Confirmed") {
        SimilarSetCardPreview(isConfirmed: true)
            .frame(height: 64)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
#endif

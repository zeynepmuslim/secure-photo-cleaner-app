//
//  MediaPreviewViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import AVFoundation
import Photos
import UIKit

/// The Delete Bin's preview of one item (board "Delete Bin media preview · Keep | Delete | Store"):
/// the media card, "Marked for Deletion" with its date and size, and a decision. Keep or Store
/// take the item out of the bin as a review decision (`onDecide`); Leave in Bin is the current
/// choice; Delete Now deletes it right away. Built like `HistoryDetailBottomSheet`.
final class MediaPreviewViewController: UIViewController {

    /// Keep or Store was chosen; called once, after the sheet closes.
    var onDecide: ((UndoAction.ActionType) -> Void)?
    var onDeleteNow: (() -> Void)?
    var onDismiss: (() -> Void)?
    /// An image to show at once instead of loading the poster (previews).
    var previewImage: UIImage?

    // MARK: - Layout

    private enum Layout {
        static let rowGap: CGFloat = 12
        static let regularActionsGap: CGFloat = 16
        static let compactActionsGap: CGFloat = 12
        static let segmentSpacing: CGFloat = 8
        static let regularSegmentHeight = GeneralConstants.ButtonSize.mediumLarge
        static let compactSegmentHeight: CGFloat = 46
        /// The current choice's segment is this much wider than each of the others, so its icon
        /// and longer title fit on the iPhone SE.
        static let currentSegmentWidthRatio: CGFloat = 1.5
        static let segmentTitleSize: CGFloat = 16
        static let segmentIconSize: CGFloat = 15
        static let segmentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        /// Compact segments keep their 16pt titles and gain room from tighter sides and icon gap,
        /// so "Çöpte Kalsın" and "Depola" fit on the iPhone SE.
        static let compactSegmentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)
        static let segmentImagePadding: CGFloat = 8
        static let compactSegmentImagePadding: CGFloat = 4
        static let regularTitleSize: CGFloat = 20
        static let compactTitleSize: CGFloat = 18
        static let deleteNowGap: CGFloat = 8
        static let maximumColumnWidth = GeneralConstants.SheetColumn.maximumWidth
        static let compactWindowHeight: CGFloat = 700
        static let playBadge: CGFloat = 40
        static let durationChipHeight: CGFloat = 22
        static let durationChipInset: CGFloat = 8
        /// The media card hugs the asset's ratio inside this range (the deck's range), so a
        /// panorama doesn't become a sliver; inside the card the media is aspect-fill.
        static let cardRatioRange: ClosedRange<CGFloat> = (9.0 / 16.0)...(16.0 / 9.0)
        /// The grown video's controls: one glass capsule under it, as wide as the video within
        /// these limits.
        static let videoBarHeight: CGFloat = 52
        static let videoBarGap: CGFloat = 12
        static let videoBarMinimumWidth: CGFloat = 360
        static let videoBarMaximumWidth: CGFloat = 560
        static let lockedAlpha: CGFloat = 0.4
    }

    private enum Timing {
        static let selectionDissolve: TimeInterval = 0.2
        /// How long the new selection shows before the sheet closes.
        static let selectionHold: TimeInterval = 0.4
        static let controlsFade: TimeInterval = 0.25
    }

    // MARK: - Views

    private let closeButton = CloseButton()

    /// The preview's room: the media card is centered in it.
    private let previewArea: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }()

    /// The photo, or a video's poster frame, as a rounded card that hugs the asset's own aspect
    /// ratio (`updateMediaCardSize`). The whole card is the tap target that enlarges it.
    private let mediaCard: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.backgroundColor = .secondarySystemFill
        view.layer.cornerRadius = GeneralConstants.CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// A video's play badge on its poster; it plays only once grown.
    private let playBadgeView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "play.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    /// A video's length in the card's bottom trailing corner.
    private let durationChip: PaddingLabel = {
        let label = PaddingLabel()
        label.textInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = Layout.durationChipHeight / 2
        label.layer.cornerCurve = .continuous
        label.clipsToBounds = true
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let capsuleView = ActionRuleCapsuleView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.regularTitleSize, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 2
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    /// "12 Aug 2025, 18:30 · 2.4 MB"
    private let metaLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let titleRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Layout.rowGap
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let actionStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.spacing = Layout.segmentSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let keepButton = DynamicGlassButton()
    private let leaveInBinButton = DynamicGlassButton()
    private let storeButton = DynamicGlassButton()

    private var segments: [(type: UndoAction.ActionType, button: DynamicGlassButton)] {
        [(.keep, keepButton), (.delete, leaveInBinButton), (.store, storeButton)]
    }

    /// Delete Now: a full-width gray glass button in red, under the segments.
    private let deleteNowButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// The content's column: the sheet's full width minus its side padding, at most 560pt wide and
    /// centered. The sheet covers the tab bar and the side bar, so the camera strip's safe area doesn't
    /// apply; only rows the camera itself overlaps narrow (`updateOcclusionClearance`).
    private let contentGuide = UILayoutGuide()

    /// A row whose sides inset only where the camera overlaps it.
    private struct OcclusionRow {
        let row: UIView
        let leading: NSLayoutConstraint
        let trailing: NSLayoutConstraint
    }
    private var occlusionRows: [OcclusionRow] = []
    /// The sheet's frame in its window when the insets were found; they only grow while it holds.
    private var occlusionFrame: CGRect = .null

    private var mediaCardWidthConstraint: NSLayoutConstraint?
    private var mediaCardHeightConstraint: NSLayoutConstraint?
    private var segmentHeightConstraints: [NSLayoutConstraint] = []
    private var actionsGapConstraint: NSLayoutConstraint?
    private var isCompact = false
    private var didApplyMetrics = false

    /// Grows the media card into a large photo over the window.
    private let growPresenter = PhotoGrowPresenter()
    /// The grown video's player; it exists only while a video is enlarged.
    private var grownVideoController: VideoPlayerController?
    private var grownVideoBarWidthConstraint: NSLayoutConstraint?
    private var grownVideoBarUnderVideoConstraint: NSLayoutConstraint?
    private var grownVideoBarOnBaseConstraint: NSLayoutConstraint?
    private let videoImageManager = PHCachingImageManager()
    /// Bumped whenever the grown photo opens or closes, so a late image load is ignored.
    private var growGeneration = 0
    private var didRequestPoster = false
    private var metadataTask: Task<Void, Never>?

    private let asset: PHAsset
    private var isVideo: Bool { asset.mediaType == .video }

    /// The choice the sheet shows: Leave in Bin until the user taps Keep or Store.
    private var selectedType: UndoAction.ActionType = .delete
    /// The tapped choice's callback while the sheet is closing; delivered exactly once.
    private var pendingCallback: (() -> Void)?
    private var dismissWorkItem: DispatchWorkItem?

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
            // No edge-attached override: the Duo's inner display gets the system's centered sheet.
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        configure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyMetricsIfNeeded()
        UIView.performWithoutAnimation {
            updateOcclusionClearance()
            updateMediaCardSize()
        }
        loadPosterIfNeeded()
        // Folding moves the sheet and changes the grown media's room.
        growPresenter.relayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // The clearance is skipped while the sheet slides in (it passes the camera on the way).
        updateOcclusionClearance()
        // A drag that started during the selection's hold and was let go: close now.
        if pendingCallback != nil, dismissWorkItem == nil {
            dismissForSelection()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        metadataTask?.cancel()
        growPresenter.dismiss(animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Dragged away during the selection's hold: the choice still counts. It runs before
        // `onDismiss`, while the bin still treats the preview as open.
        deliverPendingCallback()
        onDismiss?()
    }

    // MARK: - Setup

    private func setupUI() {
        // Opaque, so nothing behind the sheet shows through. Plain `.systemBackground` turns into
        // the iOS 26 sheet's glass; a color resolved from it per appearance stays solid.
        view.backgroundColor = UIColor { UIColor.systemBackground.resolvedColor(with: $0) }
        view.isOpaque = true

        view.addLayoutGuide(contentGuide)

        view.addSubview(previewArea)
        view.addSubview(closeButton)

        previewArea.addSubview(mediaCard)
        mediaCard.addSubview(imageView)
        mediaCard.addSubview(playBadgeView)
        mediaCard.addSubview(durationChip)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, metaLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        titleRow.addArrangedSubview(capsuleView)
        titleRow.addArrangedSubview(textStack)
        view.addSubview(titleRow)

        for (_, button) in segments {
            actionStackView.addArrangedSubview(button)
        }
        view.addSubview(actionStackView)
        view.addSubview(deleteNowButton)

        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        keepButton.addTarget(self, action: #selector(handleKeepTap), for: .touchUpInside)
        storeButton.addTarget(self, action: #selector(handleStoreTap), for: .touchUpInside)
        deleteNowButton.addTarget(self, action: #selector(handleDeleteNow), for: .touchUpInside)

        mediaCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMediaTap)))
        mediaCard.isAccessibilityElement = true
        mediaCard.accessibilityLabel = Strings.enlarge
        mediaCard.accessibilityTraits = .button

        titleRow.isAccessibilityElement = true
        deleteNowButton.accessibilityTraits = .button
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide
        let side = GeneralConstants.EdgePadding.medium

        // The column: the sheet's full width minus the padding, at most 560pt, centered.
        let preferredLeading = contentGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side)
        preferredLeading.priority = .defaultHigh
        // Down to the safe area's bottom; never closer than the padding to the sheet's edge.
        let preferredBottom = contentGuide.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        preferredBottom.priority = .defaultLow

        // Each row's sides, kept so the camera check can inset them (`updateOcclusionClearance`).
        let previewLeading = previewArea.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let previewTrailing = previewArea.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        let titleLeading = titleRow.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let titleTrailing = titleRow.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        let actionsLeading = actionStackView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let actionsTrailing = actionStackView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        let deleteNowLeading = deleteNowButton.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let deleteNowTrailing = deleteNowButton.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        occlusionRows = [
            OcclusionRow(row: previewArea, leading: previewLeading, trailing: previewTrailing),
            OcclusionRow(row: titleRow, leading: titleLeading, trailing: titleTrailing),
            OcclusionRow(row: actionStackView, leading: actionsLeading, trailing: actionsTrailing),
            OcclusionRow(row: deleteNowButton, leading: deleteNowLeading, trailing: deleteNowTrailing)
        ]

        capsuleView.translatesAutoresizingMaskIntoConstraints = false
        capsuleView.setContentHuggingPriority(.required, for: .horizontal)
        capsuleView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Sized after layout from the asset's ratio and the preview's room (`updateMediaCardSize`).
        let cardWidth = mediaCard.widthAnchor.constraint(equalToConstant: 0)
        let cardHeight = mediaCard.heightAnchor.constraint(equalToConstant: 0)
        // Below required: the card never grows past its room, whatever size it had before.
        cardWidth.priority = .defaultHigh
        cardHeight.priority = .defaultHigh
        mediaCardWidthConstraint = cardWidth
        mediaCardHeightConstraint = cardHeight

        // Delete Now is as tall as the segments, in both metrics.
        segmentHeightConstraints = (segments.map(\.button) + [deleteNowButton]).map {
            $0.heightAnchor.constraint(equalToConstant: Layout.regularSegmentHeight)
        }
        let actionsGap = actionStackView.topAnchor.constraint(
            equalTo: titleRow.bottomAnchor, constant: Layout.regularActionsGap)
        actionsGapConstraint = actionsGap

        NSLayoutConstraint.activate(segmentHeightConstraints + [
            preferredLeading,
            contentGuide.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: side),
            contentGuide.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentGuide.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumColumnWidth),
            contentGuide.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: side),
            preferredBottom,
            contentGuide.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor),
            contentGuide.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -side),

            // Close: the shared 44pt button on the safe area's top leading corner.
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side),
            closeButton.topAnchor.constraint(equalTo: contentGuide.topAnchor),

            previewArea.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: Layout.rowGap),
            previewLeading, previewTrailing,

            mediaCard.centerXAnchor.constraint(equalTo: previewArea.centerXAnchor),
            mediaCard.centerYAnchor.constraint(equalTo: previewArea.centerYAnchor),
            mediaCard.widthAnchor.constraint(lessThanOrEqualTo: previewArea.widthAnchor),
            mediaCard.heightAnchor.constraint(lessThanOrEqualTo: previewArea.heightAnchor),
            cardWidth, cardHeight,

            imageView.topAnchor.constraint(equalTo: mediaCard.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: mediaCard.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: mediaCard.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: mediaCard.bottomAnchor),

            playBadgeView.centerXAnchor.constraint(equalTo: mediaCard.centerXAnchor),
            playBadgeView.centerYAnchor.constraint(equalTo: mediaCard.centerYAnchor),
            playBadgeView.widthAnchor.constraint(equalToConstant: Layout.playBadge),
            playBadgeView.heightAnchor.constraint(equalToConstant: Layout.playBadge),

            durationChip.trailingAnchor.constraint(equalTo: mediaCard.trailingAnchor, constant: -Layout.durationChipInset),
            durationChip.bottomAnchor.constraint(equalTo: mediaCard.bottomAnchor, constant: -Layout.durationChipInset),
            durationChip.heightAnchor.constraint(equalToConstant: Layout.durationChipHeight),

            capsuleView.widthAnchor.constraint(equalToConstant: ActionRuleCapsuleView.size.width),
            capsuleView.heightAnchor.constraint(equalToConstant: ActionRuleCapsuleView.size.height),

            titleRow.topAnchor.constraint(equalTo: previewArea.bottomAnchor, constant: Layout.rowGap),
            titleLeading, titleTrailing,

            // Keep and Store share a width; the current choice is half again as wide.
            keepButton.widthAnchor.constraint(equalTo: storeButton.widthAnchor),
            leaveInBinButton.widthAnchor.constraint(
                equalTo: keepButton.widthAnchor, multiplier: Layout.currentSegmentWidthRatio),

            actionsGap,
            actionsLeading, actionsTrailing,

            deleteNowButton.topAnchor.constraint(equalTo: actionStackView.bottomAnchor, constant: Layout.deleteNowGap),
            deleteNowLeading, deleteNowTrailing,
            deleteNowButton.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor)
        ])
    }

    private func configure() {
        imageView.image = previewImage
        playBadgeView.isHidden = !isVideo
        if isVideo {
            durationChip.text = DateFormatterManager.shared.formatVideoDuration(asset.duration)
            durationChip.isHidden = false
        }
        capsuleView.configure(type: .delete, color: UndoAction.ActionType.delete.displayColor)
        titleLabel.text = Strings.markedForDeletion
        configureDeleteNowButton()
        updateMeta(size: nil)
        loadFileSize()
        applySegmentStyles(animated: false)
    }

    private var segmentInsets: NSDirectionalEdgeInsets {
        isCompact ? Layout.compactSegmentInsets : Layout.segmentInsets
    }

    private var segmentImagePadding: CGFloat {
        isCompact ? Layout.compactSegmentImagePadding : Layout.segmentImagePadding
    }

    private func configureDeleteNowButton() {
        let symbol = UIImage(
            systemName: "trash.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.segmentIconSize, weight: .semibold))
        // Clear glass repaints template symbols in its own ink, so the symbol is drawn in red.
        deleteNowButton.configure(
            title: Strings.deleteNow,
            image: symbol?.withTintColor(.systemRed, renderingMode: .alwaysOriginal), style: .regular,
            backgroundColor: .tertiarySystemFill, foregroundColor: .systemRed,
            fontSize: Layout.segmentTitleSize, contentInsets: segmentInsets)
        deleteNowButton.configuration?.imagePadding = segmentImagePadding
        deleteNowButton.configuration?.titleLineBreakMode = .byTruncatingTail
        deleteNowButton.titleLabel?.numberOfLines = 1
    }

    // MARK: - Title row

    private var dateText: String? {
        asset.creationDate.map { DateFormatterManager.shared.dayMonthTime(from: $0) }
    }

    private func updateMeta(size: Int64?) {
        let sizeText = size.flatMap { $0 > 0 ? $0.formattedBytes() : nil }
        let parts = [dateText, sizeText].compactMap { $0 }
        metaLabel.text = parts.joined(separator: " · ")
        titleRow.accessibilityLabel = ([Strings.markedForDeletion] + parts).joined(separator: ", ")
    }

    /// The size takes a resource lookup, so it's read off main.
    private func loadFileSize() {
        let asset = asset
        metadataTask?.cancel()
        metadataTask = Task { [weak self] in
            let size = await Task.detached(priority: .userInitiated) {
                asset.resourceMetadata().fileSize
            }.value
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.updateMeta(size: size) }
        }
    }

    // MARK: - Segments

    private func segmentTitle(for type: UndoAction.ActionType) -> String {
        switch type {
        case .keep: return Strings.keep
        case .delete: return Strings.leaveInBin
        case .store: return Strings.store
        }
    }

    /// The history toolbar's filled symbols (a circled tick for Keep).
    private func segmentSymbol(for type: UndoAction.ActionType) -> String {
        switch type {
        case .keep: return "checkmark.circle.fill"
        case .delete: return "trash.fill"
        case .store: return "archivebox.fill"
        }
    }

    /// Restyles the three segments from `selectedType`. The chosen one is glass filled with its
    /// color and can't be tapped; the others are clear glass with the colored icon.
    private func applySegmentStyles(animated: Bool) {
        let styleSegments = {
            for (type, button) in self.segments {
                self.applyStyle(to: button, type: type, isSelected: type == self.selectedType)
            }
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            styleSegments()
            return
        }
        UIView.transition(
            with: actionStackView, duration: Timing.selectionDissolve, options: .transitionCrossDissolve,
            animations: styleSegments)
    }

    private func applyStyle(to button: DynamicGlassButton, type: UndoAction.ActionType, isSelected: Bool) {
        let color = type.displayColor
        let symbol = UIImage(
            systemName: segmentSymbol(for: type),
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.segmentIconSize, weight: .semibold))
        if isSelected {
            button.configure(
                title: segmentTitle(for: type), image: symbol, style: .prominent,
                backgroundColor: color, foregroundColor: type.displayInk,
                fontSize: Layout.segmentTitleSize, contentInsets: segmentInsets)
        } else {
            // Clear glass repaints template symbols in its own ink, so the symbol is drawn in its color.
            button.configure(
                title: segmentTitle(for: type),
                image: symbol?.withTintColor(color, renderingMode: .alwaysOriginal), style: .regular,
                backgroundColor: .tertiarySystemFill, foregroundColor: .label,
                fontSize: Layout.segmentTitleSize, contentInsets: segmentInsets)
        }
        button.configuration?.imagePadding = segmentImagePadding
        button.configuration?.titleLineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        // Not `isEnabled = false`: a disabled glass button dims to half.
        let isDeciding = pendingCallback != nil
        let isLocked = isSelected || isDeciding
        button.isUserInteractionEnabled = !isLocked
        button.alpha = isDeciding && !isSelected ? Layout.lockedAlpha : 1
        var traits: UIAccessibilityTraits = .button
        if isSelected { traits.insert(.selected) }
        if isLocked { traits.insert(.notEnabled) }
        button.accessibilityTraits = traits
    }

    /// Shows the tapped choice, then closes the sheet and hands it over.
    private func select(_ type: UndoAction.ActionType) {
        guard pendingCallback == nil, type != selectedType, type != .delete else { return }
        pendingCallback = { [weak self] in self?.onDecide?(type) }
        selectedType = type
        closeButton.isEnabled = false
        deleteNowButton.isUserInteractionEnabled = false
        deleteNowButton.alpha = Layout.lockedAlpha
        applySegmentStyles(animated: true)
        HapticFeedbackManager.shared.selection()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.dismissWorkItem = nil
            self.dismissForSelection()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.selectionHold, execute: workItem)
    }

    private func dismissForSelection() {
        dismiss(animated: true) { [weak self] in
            self?.deliverPendingCallback()
        }
    }

    /// Runs the chosen callback once, whichever way the sheet went away.
    private func deliverPendingCallback() {
        guard let callback = pendingCallback else { return }
        pendingCallback = nil
        callback()
    }

    // MARK: - Metrics

    /// Compact: a short phone (iPhone SE, the Duo's cover display), or a Duo inner display where
    /// the sheet gets little room (upright: below the fold; book pose: the leading half).
    private func shouldUseCompactMetrics() -> Bool {
        let window = view.window ?? presentingViewController?.view.window
        let windowHeight = window?.bounds.height ?? view.bounds.height
        if traitCollection.horizontalSizeClass == .compact, windowHeight <= Layout.compactWindowHeight {
            return true
        }
        if #available(iOS 27.1, *), let presenterView = presentingViewController?.view {
            if let fold = FoldRegion.splittingFold(in: presenterView), fold.width > fold.height,
               presenterView.traitCollection.horizontalSizeClass == .regular {
                return true
            }
            if let fold = FoldRegion.activeFold(in: presenterView), fold.height > fold.width {
                return true
            }
        }
        return false
    }

    private func applyMetricsIfNeeded() {
        let compact = shouldUseCompactMetrics()
        guard compact != isCompact || !didApplyMetrics else { return }
        didApplyMetrics = true
        isCompact = compact
        let segmentHeight = compact ? Layout.compactSegmentHeight : Layout.regularSegmentHeight
        segmentHeightConstraints.forEach { $0.constant = segmentHeight }
        actionsGapConstraint?.constant = compact ? Layout.compactActionsGap : Layout.regularActionsGap
        titleLabel.font = .systemFont(
            ofSize: compact ? Layout.compactTitleSize : Layout.regularTitleSize, weight: .bold)
        // The segments' sides and icon gap follow the metrics.
        applySegmentStyles(animated: false)
        configureDeleteNowButton()
    }

    // MARK: - Media card

    /// The asset's own width / height: its pixel size, else the image's, else square.
    private var mediaAspectRatio: CGFloat {
        if asset.pixelWidth > 0, asset.pixelHeight > 0 {
            return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        }
        if let size = imageView.image?.size, size.width > 0, size.height > 0 {
            return size.width / size.height
        }
        return 1
    }

    /// The card hugs the asset's ratio (clamped), as large as fits the preview's room.
    private func updateMediaCardSize() {
        let room = previewArea.bounds.size
        guard room.width > 0, room.height > 0 else { return }
        let ratio = min(max(mediaAspectRatio, Layout.cardRatioRange.lowerBound), Layout.cardRatioRange.upperBound)
        let width = min(room.width, room.height * ratio).rounded(.down)
        let height = min(room.height, width / ratio).rounded(.down)
        if mediaCardWidthConstraint?.constant != width {
            mediaCardWidthConstraint?.constant = width
        }
        if mediaCardHeightConstraint?.constant != height {
            mediaCardHeightConstraint?.constant = height
        }
    }

    /// The photo, or a video's poster, at preview quality for the sheet's size; once.
    private func loadPosterIfNeeded() {
        guard !didRequestPoster, previewImage == nil, view.bounds.width > 0 else { return }
        didRequestPoster = true
        ImageCacheService.shared.loadImage(
            for: asset,
            quality: .preview,
            screenSize: view.bounds.size,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
            traitCollection: traitCollection
        ) { [weak self] image, _, _ in
            DispatchQueue.main.async {
                guard let self, let image else { return }
                self.imageView.image = image
            }
        }
    }

    // MARK: - iPhone Duo camera

    /// Rows the camera overlaps (the Duo's cover display) narrow evenly on both sides; the others
    /// keep the full width. While the sheet stays where it is an inset only grows. Skipped while
    /// the sheet slides in or out; `viewDidAppear` runs it again.
    private func updateOcclusionClearance() {
        guard view.window != nil, transitionCoordinator == nil else { return }
        var cameras: [CGRect] = []
        if #available(iOS 27.1, *) {
            cameras = view.reservedRegions(kind: .occlusion).map(\.frame)
        }
        let sheetFrame = view.convert(view.bounds, to: nil)
        let frameChanged = sheetFrame != occlusionFrame
        occlusionFrame = sheetFrame
        let column = contentGuide.layoutFrame
        var changed = false
        for entry in occlusionRows {
            let rowFrame = CGRect(x: column.minX, y: entry.row.frame.minY, width: column.width, height: entry.row.frame.height)
            var inset: CGFloat = frameChanged ? 0 : entry.trailing.constant.magnitude
            if rowFrame.width > 0 {
                for camera in cameras where camera.intersects(rowFrame) {
                    // How far the camera reaches into the row from the edge it sits on.
                    let overlap = camera.midX > rowFrame.midX ? rowFrame.maxX - camera.minX : camera.maxX - rowFrame.minX
                    inset = max(inset, min(overlap, rowFrame.width / 4))
                }
            }
            guard entry.trailing.constant != -inset else { continue }
            entry.leading.constant = inset
            entry.trailing.constant = -inset
            changed = true
        }
        if changed { view.layoutIfNeeded() }
    }

    // MARK: - Actions

    @objc private func handleCloseTap() {
        dismiss(animated: true)
    }

    @objc private func handleKeepTap() {
        select(.keep)
    }

    @objc private func handleStoreTap() {
        select(.store)
    }

    @objc private func handleDeleteNow() {
        guard pendingCallback == nil else { return }
        onDeleteNow?()
    }

    // MARK: - Enlarged media

    /// Grows the card into a large photo over the window; a video then plays there.
    @objc private func handleMediaTap() {
        guard !growPresenter.isPresented, pendingCallback == nil,
              let window = view.window, let image = imageView.image else { return }
        growGeneration += 1
        let generation = growGeneration

        growPresenter.onWillShow = { [weak self] in self?.mediaCard.alpha = 0 }
        growPresenter.onDidDismiss = { [weak self] in self?.mediaCard.alpha = 1 }
        growPresenter.onDidShow = { [weak self] in
            guard let self, self.growGeneration == generation else { return }
            if self.isVideo {
                self.startGrownVideo()
            } else {
                self.loadFullImage(in: window, generation: generation)
            }
        }
        growPresenter.onWillDismiss = { [weak self] in
            self?.growGeneration += 1
            self?.stopGrownVideo()
        }
        growPresenter.onImageTap = isVideo ? { [weak self] in self?.toggleGrownVideo() } : nil
        growPresenter.onLayout = { [weak self] in self?.layoutGrownVideo() }

        growPresenter.present(
            in: window, image: image, aspectRatio: mediaAspectRatio,
            sourceCornerRadius: GeneralConstants.CornerRadius.card,
            accessibilityLabel: isVideo ? Strings.enlargedVideo : Strings.enlargedPhoto,
            showsCloseButton: true,
            availableRect: { [weak self] window in
                self?.growRoom(in: window, reservesVideoBar: true) ?? window.bounds.inset(by: window.safeAreaInsets)
            },
            // Asked again when shrinking: the sheet can move meanwhile.
            sourceFrame: { [weak self] in
                guard let self, self.mediaCard.window != nil else { return nil }
                return self.mediaCard.convert(self.mediaCard.bounds, to: nil)
            })
    }

    /// The room the grown media may fill: the window's safe area. Table pose: the raised half (a
    /// video's controls sit on the base). Book pose: the larger side of the fold. Outside the
    /// table pose a video leaves room under it for its controls.
    private func growRoom(in window: UIWindow, reservesVideoBar: Bool) -> CGRect {
        var room = window.bounds.inset(by: window.safeAreaInsets)
        if let fold = tableFold(in: window) {
            let raised = CGRect(x: room.minX, y: room.minY, width: room.width, height: fold.minY - room.minY)
            if raised.height > 0 { return raised }
        }
        if let fold = FoldRegion.activeFold(in: window) {
            let sides: [CGRect]
            if FoldRegion.pose(for: fold) == .book {
                sides = [
                    CGRect(x: room.minX, y: room.minY, width: fold.minX - room.minX, height: room.height),
                    CGRect(x: fold.maxX, y: room.minY, width: room.maxX - fold.maxX, height: room.height)
                ]
            } else {
                sides = [
                    CGRect(x: room.minX, y: room.minY, width: room.width, height: fold.minY - room.minY),
                    CGRect(x: room.minX, y: fold.maxY, width: room.width, height: room.maxY - fold.maxY)
                ]
            }
            let usable = sides.filter { $0.width > 0 && $0.height > 0 }
            if let larger = usable.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                room = larger
            }
        }
        if reservesVideoBar, isVideo {
            room.size.height = max(room.height - Layout.videoBarHeight - Layout.videoBarGap, 1)
        }
        return room
    }

    /// Once grown, the photo is loaded at full quality for the window's size. A failed load
    /// leaves the image that is already showing.
    private func loadFullImage(in window: UIWindow, generation: Int) {
        ImageCacheService.shared.loadImage(
            for: asset,
            quality: .full,
            screenSize: window.bounds.size,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
            traitCollection: window.traitCollection
        ) { [weak self] image, _, _ in
            DispatchQueue.main.async {
                guard let self, let image, self.growGeneration == generation else { return }
                self.growPresenter.setImage(image)
            }
        }
    }

    /// The fold while the device is in the table pose (a horizontal band across the window).
    private func tableFold(in window: UIWindow) -> CGRect? {
        guard let fold = FoldRegion.activeFold(in: window), FoldRegion.pose(for: fold) == .table else { return nil }
        return fold
    }

    /// Loads the video over the grown poster and plays it, with one glass capsule of controls
    /// centered under it. A tap on the video toggles play / pause. A failed load leaves the poster.
    private func startGrownVideo() {
        guard let overlay = growPresenter.overlayView, let poster = growPresenter.imageView,
              let window = overlay.window else { return }
        let controller = VideoPlayerController(configuration: .init(
            videoGravity: .resizeAspect,
            layerCornerRadius: PhotoGrowPresenter.grownCornerRadius
        ))
        grownVideoController = controller
        controller.setControlsLayout(.bar)

        let bar = controller.controlsContainer
        bar.alpha = 0
        overlay.addSubview(bar)

        let barWidth = bar.widthAnchor.constraint(equalToConstant: grownVideoBarWidth(in: window))
        grownVideoBarWidthConstraint = barWidth
        // Under the video, or in the table pose centered on the base (`layoutGrownVideo`).
        let underVideo = bar.topAnchor.constraint(equalTo: poster.bottomAnchor, constant: Layout.videoBarGap)
        let onBase = bar.centerYAnchor.constraint(equalTo: overlay.topAnchor)
        grownVideoBarUnderVideoConstraint = underVideo
        grownVideoBarOnBaseConstraint = onBase
        NSLayoutConstraint.activate([
            bar.centerXAnchor.constraint(equalTo: poster.centerXAnchor),
            barWidth,
            underVideo,
            bar.heightAnchor.constraint(equalToConstant: Layout.videoBarHeight)
        ])
        layoutGrownVideo()

        controller.onStateChanged = { [weak self, weak controller] state in
            guard let self, let controller, self.grownVideoController === controller,
                  let poster = self.growPresenter.imageView else { return }
            guard case .ready = state, let layer = controller.playerLayer else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = poster.bounds
            poster.layer.addSublayer(layer)
            CATransaction.commit()
            controller.play()
            UIView.animate(withDuration: Timing.controlsFade) {
                controller.controlsContainer.alpha = 1
            }
        }
        controller.loadVideo(
            from: asset,
            using: videoImageManager,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        )
    }

    /// The bar is as wide as the video, within its limits and the video's room.
    private func grownVideoBarWidth(in window: UIWindow) -> CGFloat {
        let room = growRoom(in: window, reservesVideoBar: false)
        let videoWidth = growPresenter.imageView?.bounds.width ?? 0
        let wanted = min(max(videoWidth, Layout.videoBarMinimumWidth), Layout.videoBarMaximumWidth)
        return max(min(wanted, room.width - GeneralConstants.EdgePadding.medium * 2), 1)
    }

    /// The grown video moved (the window or the fold changed): its layer and bar follow it.
    private func layoutGrownVideo() {
        guard let controller = grownVideoController, let poster = growPresenter.imageView,
              let window = poster.window else { return }
        controller.playerLayer?.frame = poster.bounds
        let width = grownVideoBarWidth(in: window)
        if grownVideoBarWidthConstraint?.constant != width {
            grownVideoBarWidthConstraint?.constant = width
        }
        guard let underVideo = grownVideoBarUnderVideoConstraint,
              let onBase = grownVideoBarOnBaseConstraint else { return }
        if let fold = tableFold(in: window) {
            let baseBottom = window.bounds.maxY - window.safeAreaInsets.bottom
            onBase.constant = (fold.maxY + baseBottom) / 2
            if underVideo.isActive { underVideo.isActive = false }
            if !onBase.isActive { onBase.isActive = true }
        } else {
            if onBase.isActive { onBase.isActive = false }
            if !underVideo.isActive { underVideo.isActive = true }
        }
    }

    private func toggleGrownVideo() {
        guard let controller = grownVideoController, controller.playerLayer != nil else { return }
        controller.togglePlayPause()
    }

    /// Stops the video and takes its layer and controls off the overlay, before the poster shrinks back.
    private func stopGrownVideo() {
        guard let controller = grownVideoController else { return }
        grownVideoController = nil
        grownVideoBarWidthConstraint = nil
        grownVideoBarUnderVideoConstraint = nil
        grownVideoBarOnBaseConstraint = nil
        controller.onStateChanged = nil
        controller.pause()
        controller.cleanup()
        controller.controlsContainer.removeFromSuperview()
    }
}

// MARK: - Strings

private enum Strings {
    static let keep = CommonStrings.keep
    static let store = CommonStrings.store
    static let leaveInBin = NSLocalizedString(
        "mediaPreview.leaveInBin", comment: "The bin preview's current choice: the item stays in the Delete Bin")
    static let deleteNow = NSLocalizedString("mediaPreview.deleteNow", comment: "Delete now button")
    /// The bin item's title is the delete action's own title.
    static var markedForDeletion: String { UndoAction.ActionType.delete.displayTitle }
    static let enlarge = NSLocalizedString(
        "mediaPreview.enlarge", comment: "Accessibility label of the photo or video card; a tap enlarges it")
    static let enlargedPhoto = NSLocalizedString(
        "mediaPreview.enlargedPhoto", comment: "Accessibility label of the enlarged photo")
    static let enlargedVideo = NSLocalizedString(
        "mediaPreview.enlargedVideo", comment: "Accessibility label of the enlarged video")
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview {
        let vc = MediaPreviewViewController(asset: PHAsset())
        vc.previewImage = UIImage(named: "exampleImage")
        return vc
    }
#endif

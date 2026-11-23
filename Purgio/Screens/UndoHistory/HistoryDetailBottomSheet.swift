//
//  HistoryDetailBottomSheet.swift
//  Purgio
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

    // MARK: - Layout

    private enum Layout {
        static let rowGap: CGFloat = 12
        static let actionsGap: CGFloat = 16
        static let segmentSpacing: CGFloat = 8
        static let segmentHeight = GeneralConstants.ButtonSize.mediumLarge
        static let segmentTitleSize: CGFloat = 16
        static let segmentIconSize: CGFloat = 15
        static let segmentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        static let playBadge: CGFloat = 40
        /// The media card hugs the asset's ratio inside this range (the deck's range), so a
        /// panorama doesn't become a sliver; inside the card the media is aspect-fill.
        static let cardRatioRange: ClosedRange<CGFloat> = (9.0 / 16.0)...(16.0 / 9.0)
        /// The grown video's controls: one glass capsule under it (play, time, scrubber, duration,
        /// sound), as wide as the video within these limits.
        static let videoBarHeight: CGFloat = 52
        static let videoBarGap: CGFloat = 12
        static let videoBarMinimumWidth: CGFloat = 360
        static let videoBarMaximumWidth: CGFloat = 560
    }

    private enum Timing {
        static let selectionDissolve: TimeInterval = 0.2
        /// How long the new selection shows before the sheet closes.
        static let selectionHold: TimeInterval = 0.4
        static let controlsFade: TimeInterval = 0.25
    }

    // MARK: - Views

    private let closeButton = CloseButton()

    /// The preview's room: the media card is centered in it. It is the row the camera check
    /// narrows and the fold's leading column, so it has no look of its own.
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

    private let capsuleView = ActionRuleCapsuleView()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 2
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let timeLabel: UILabel = {
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
        stack.distribution = .fillEqually
        stack.spacing = Layout.segmentSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var segments: [(type: UndoAction.ActionType, button: DynamicGlassButton)] {
        [(.keep, keepButton), (.delete, deleteButton), (.store, storeButton)]
    }

    private lazy var keepButton = makeActionSegment()
    private lazy var deleteButton = makeActionSegment()
    private lazy var storeButton = makeActionSegment()

    /// A video's play badge on its poster; nothing plays in the sheet.
    private let playBadgeView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "play.fill"))
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    /// The content's area: the sheet's full width minus its side padding. The sheet covers the tab
    /// bar and the side bar, so the camera strip's safe area doesn't apply; only rows the camera
    /// itself overlaps narrow (`updateOcclusionClearance`).
    private let contentGuide = UILayoutGuide()

    /// A row whose sides inset only where the camera overlaps it. The sheet is one column on every
    /// display: the Duo's inner display gets the system's own centered sheet.
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

    private let action: UndoAction
    private let image: UIImage?
    private let asset: PHAsset?
    private var isVideo: Bool { asset?.mediaType == .video }

    /// The action the sheet shows as chosen: the recorded one until the user taps another.
    private var selectedType: UndoAction.ActionType
    /// The tapped action's callback while the sheet is closing; delivered exactly once.
    private var pendingCallback: (() -> Void)?
    private var dismissWorkItem: DispatchWorkItem?

    init(action: UndoAction, image: UIImage?, asset: PHAsset? = nil) {
        self.action = action
        self.image = image
        self.asset = asset
        self.selectedType = action.actionType
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
        updateLayout()
        UIView.performWithoutAnimation {
            updateOcclusionClearance()
            updateMediaCardSize()
        }
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
        growPresenter.dismiss(animated: false)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Dragged away during the selection's hold: the choice still counts.
        deliverPendingCallback()
    }

    // MARK: - Setup

    private func setupUI() {
        // Opaque, so nothing behind the sheet shows through in dark mode. Plain `.systemBackground`
        // turns into the iOS 26 sheet's glass; a color resolved from it per appearance stays solid.
        view.backgroundColor = UIColor { UIColor.systemBackground.resolvedColor(with: $0) }
        view.isOpaque = true

        view.addLayoutGuide(contentGuide)

        view.addSubview(previewArea)
        view.addSubview(closeButton)

        previewArea.addSubview(mediaCard)
        mediaCard.addSubview(imageView)
        mediaCard.addSubview(playBadgeView)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, timeLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        titleRow.addArrangedSubview(capsuleView)
        titleRow.addArrangedSubview(textStack)
        view.addSubview(titleRow)

        actionStackView.addArrangedSubview(keepButton)
        actionStackView.addArrangedSubview(deleteButton)
        actionStackView.addArrangedSubview(storeButton)
        view.addSubview(actionStackView)

        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        keepButton.addTarget(self, action: #selector(handleKeepTap), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)
        storeButton.addTarget(self, action: #selector(handleStoreTap), for: .touchUpInside)

        mediaCard.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleMediaTap)))
        mediaCard.isAccessibilityElement = true
        mediaCard.accessibilityLabel = Strings.enlarge
        mediaCard.accessibilityTraits = .button
    }

    private func setupConstraint() {
        let safeArea = view.safeAreaLayoutGuide
        let side = GeneralConstants.EdgePadding.medium
        // The sheet's full width (it covers the side bar); rows under the camera narrow on their own.
        let leading = contentGuide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: side)
        let trailing = contentGuide.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -side)

        // Each row's sides, kept so the camera check can inset them (`updateOcclusionClearance`).
        let previewLeading = previewArea.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let previewTrailing = previewArea.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        let titleLeading = titleRow.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let titleTrailing = titleRow.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        let actionsLeading = actionStackView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor)
        let actionsTrailing = actionStackView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor)
        occlusionRows = [
            OcclusionRow(row: previewArea, leading: previewLeading, trailing: previewTrailing),
            OcclusionRow(row: titleRow, leading: titleLeading, trailing: titleTrailing),
            OcclusionRow(row: actionStackView, leading: actionsLeading, trailing: actionsTrailing)
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

        NSLayoutConstraint.activate([
            leading, trailing,
            contentGuide.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: GeneralConstants.EdgePadding.medium),
            contentGuide.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -GeneralConstants.EdgePadding.medium),

            // Close: the shared 44pt button (it sizes itself) on the content's corner.
            closeButton.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor),
            closeButton.topAnchor.constraint(equalTo: contentGuide.topAnchor),

            // Preview: under the close row.
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

            capsuleView.widthAnchor.constraint(equalToConstant: ActionRuleCapsuleView.size.width),
            capsuleView.heightAnchor.constraint(equalToConstant: ActionRuleCapsuleView.size.height),

            keepButton.heightAnchor.constraint(equalToConstant: Layout.segmentHeight),
            deleteButton.heightAnchor.constraint(equalToConstant: Layout.segmentHeight),
            storeButton.heightAnchor.constraint(equalToConstant: Layout.segmentHeight),

            titleRow.topAnchor.constraint(equalTo: previewArea.bottomAnchor, constant: Layout.rowGap),
            titleLeading, titleTrailing,

            actionStackView.topAnchor.constraint(equalTo: titleRow.bottomAnchor, constant: Layout.actionsGap),
            actionsLeading, actionsTrailing,
            actionStackView.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor)
        ])
    }

    private func configure() {
        imageView.image = image
        mediaCard.isHidden = image == nil
        timeLabel.text = action.timestamp.timeAgo()
        playBadgeView.isHidden = !isVideo
        applySegmentStyles(animated: false)
    }

    /// A Keep / Delete / Store glass capsule; its look comes from `applySegmentStyles(animated:)`.
    private func makeActionSegment() -> DynamicGlassButton {
        DynamicGlassButton()
    }

    private func segmentTitle(for type: UndoAction.ActionType) -> String {
        switch type {
        case .keep: return Strings.keep
        case .delete: return Strings.delete
        case .store: return Strings.store
        }
    }

    /// The segments use the history toolbar's filled symbols (a circled tick for Keep); the bare
    /// ones are the rule capsule's.
    private func segmentSymbol(for type: UndoAction.ActionType) -> String {
        switch type {
        case .keep: return "checkmark.circle.fill"
        case .delete: return "trash.fill"
        case .store: return "archivebox.fill"
        }
    }

    // MARK: - Selection

    /// Restyles the three segments and the title row from `selectedType`. The chosen segment is
    /// glass filled with its color and can't be tapped; the others are clear glass with the
    /// colored icon. Every segment keeps its own icon: the fill and the ink alone show the choice.
    private func applySegmentStyles(animated: Bool) {
        let styleSegments = {
            for (type, button) in self.segments {
                self.applyStyle(to: button, type: type, isSelected: type == self.selectedType)
            }
        }
        let styleTitleRow = {
            self.capsuleView.configure(type: self.selectedType, color: self.selectedType.displayColor)
            self.titleLabel.text = self.selectedType.displayTitle
        }
        guard animated, !UIAccessibility.isReduceMotionEnabled else {
            styleSegments()
            styleTitleRow()
            return
        }
        UIView.transition(
            with: actionStackView, duration: Timing.selectionDissolve, options: .transitionCrossDissolve,
            animations: styleSegments)
        UIView.transition(
            with: titleRow, duration: Timing.selectionDissolve, options: .transitionCrossDissolve,
            animations: styleTitleRow)
    }

    private func applyStyle(to button: DynamicGlassButton, type: UndoAction.ActionType, isSelected: Bool) {
        let color = type.displayColor
        let symbol = UIImage(
            systemName: segmentSymbol(for: type),
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.segmentIconSize, weight: .semibold))
        if isSelected {
            // Filled with the action's color; title and symbol in its ink, as on the rule capsule.
            button.configure(
                title: segmentTitle(for: type), image: symbol, style: .prominent,
                backgroundColor: color, foregroundColor: type.displayInk,
                fontSize: Layout.segmentTitleSize, contentInsets: Layout.segmentInsets)
        } else {
            // Clear glass repaints template symbols in its own ink, so the symbol is drawn in its color.
            button.configure(
                title: segmentTitle(for: type),
                image: symbol?.withTintColor(color, renderingMode: .alwaysOriginal), style: .regular,
                backgroundColor: .tertiarySystemFill, foregroundColor: .label,
                fontSize: Layout.segmentTitleSize, contentInsets: Layout.segmentInsets)
        }
        button.configuration?.titleLineBreakMode = .byTruncatingTail
        button.titleLabel?.numberOfLines = 1
        // Not `isEnabled = false`: a disabled glass button dims to half.
        let isLocked = isSelected || pendingCallback != nil
        button.isUserInteractionEnabled = !isLocked
        var traits: UIAccessibilityTraits = .button
        if isSelected { traits.insert(.selected) }
        if isLocked { traits.insert(.notEnabled) }
        button.accessibilityTraits = traits
    }

    /// Shows the tapped action as chosen, then closes the sheet and hands the choice over.
    private func select(_ type: UndoAction.ActionType) {
        guard pendingCallback == nil, type != selectedType else { return }
        let callback: (() -> Void)?
        switch type {
        case .keep: callback = onKeepTapped
        case .delete: callback = onDeleteTapped
        case .store: callback = onStoreTapped
        }
        pendingCallback = callback ?? {}
        selectedType = type
        closeButton.isEnabled = false
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

    /// Runs the tapped action's callback once, whichever way the sheet went away.
    private func deliverPendingCallback() {
        guard let callback = pendingCallback else { return }
        pendingCallback = nil
        callback()
    }

    // MARK: - Media card

    /// The asset's own width / height: its pixel size, else the image's, else square.
    private var mediaAspectRatio: CGFloat {
        if let asset, asset.pixelWidth > 0, asset.pixelHeight > 0 {
            return CGFloat(asset.pixelWidth) / CGFloat(asset.pixelHeight)
        }
        if let size = image?.size, size.width > 0, size.height > 0 {
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

    // MARK: - iPhone Duo camera

    /// Rows the camera overlaps (the Duo's cover display) narrow evenly on both sides; the others
    /// keep the full width. A narrower title can wrap and move the rows below it out from under
    /// the camera and back on the next pass, so while the sheet stays where it is an inset only
    /// grows. Skipped while the sheet slides in or out; `viewDidAppear` runs it again.
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

    // MARK: - Layout updates

    private func updateLayout() {
        let titleSize: CGFloat = traitCollection.horizontalSizeClass == .regular ? 22 : 20
        if titleLabel.font.pointSize != titleSize {
            titleLabel.font = .systemFont(ofSize: titleSize, weight: .bold)
        }
    }

    // MARK: - Actions

    @objc private func handleCloseTap() {
        dismiss(animated: true)
    }

    @objc private func handleKeepTap() {
        select(.keep)
    }

    @objc private func handleDeleteTap() {
        select(.delete)
    }

    @objc private func handleStoreTap() {
        select(.store)
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

    /// The room the grown media may fill: the window's safe area, which may cross the fold line
    /// while the Duo is fully open. Table pose: the raised half (a video's controls sit on the
    /// base). Book pose: the larger side of the fold. Outside the table pose a video leaves room
    /// under it for its controls.
    private func growRoom(in window: UIWindow, reservesVideoBar: Bool) -> CGRect {
        var room = window.bounds.inset(by: window.safeAreaInsets)
        if let fold = tableFold(in: window) {
            // Table pose: the media stands on the raised half; a video's controls go on the base.
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
        guard let asset else { return }
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

    /// Loads the video over the grown poster and plays it. Its controls are one glass capsule
    /// centered under it: play, time, scrubber, duration, sound. A tap on the video also toggles
    /// play / pause. A failed load leaves the poster.
    private func startGrownVideo() {
        guard let asset, let overlay = growPresenter.overlayView, let poster = growPresenter.imageView,
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

    /// The bar is as wide as the video, within its limits and the video's room, so it stays off
    /// the fold while partly folded.
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
            // The base: from the fold to the safe area's bottom.
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
    static let keep = NSLocalizedString("historyDetail.keep", comment: "Keep action button")
    static let delete = NSLocalizedString("historyDetail.delete", comment: "Delete action button")
    static let store = NSLocalizedString("historyDetail.store", comment: "Store action button")
    static let enlarge = NSLocalizedString(
        "historyDetail.enlarge", comment: "Accessibility label of the photo or video card; a tap enlarges it")
    static let enlargedPhoto = NSLocalizedString(
        "historyDetail.enlargedPhoto", comment: "Accessibility label of the enlarged photo")
    static let enlargedVideo = NSLocalizedString(
        "historyDetail.enlargedVideo", comment: "Accessibility label of the enlarged video")
}

// MARK: - Preview

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


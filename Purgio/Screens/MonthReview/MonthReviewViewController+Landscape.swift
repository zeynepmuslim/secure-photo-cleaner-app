//
//  MonthReviewViewController+Landscape.swift
//  Purgio
//
//  Created by ZeynepMüslim on 08.11.2026.
//

import Photos
import UIKit

private enum Strings {
    static let delete = CommonStrings.delete
    static let keep = NSLocalizedString("monthReview.keep", comment: "Keep swipe action label")
    static let store = NSLocalizedString("monthReview.store", comment: "Store swipe action label")
    static let undo = NSLocalizedString("monthReview.undo", comment: "Undo button title in the sideways layout")
    static let history = NSLocalizedString("monthReview.history", comment: "Undo history button title in the sideways layout")
}

// iPhone Duo inner display held sideways (regular width, wider than tall), boards L7b / L7d–f:
// - A grip on each side: Store + Delete on the left, Store + Keep on the right. They run the
//   same code as an up, left or right swipe.
// - Above the card the stats pill (ReviewStatsPillView), as on every inner-display layout.
// - Between them each card hugs its own photo's aspect ratio and the next cards fan out behind
//   the top one. Every card's ratio is clamped to 9:16…16:9 (an extreme photo is fitted over a
//   blurred copy of itself), so a card keeps its shape as it comes to the top. On a swipe or grip tap the deck moves into
//   its new places while the top card flies off, and the card joining the back fades in.
//   A video fills the card area and its controls split into two capsules at the fold.
// - The bottom row splits at the fold: Undo + History before it, the global bin button's slot
//   after it.
// The cover display and the upright inner display keep the standard layout.
extension MonthReviewViewController {

    /// Sideways (grips, pills) and in the table pose (the base's tray) the controls are white cards,
    /// so the screen gets the grouped background.
    var screenBackgroundColor: UIColor {
        isLandscapeDeckActive || currentFoldPose == .table ? .mainBackground : .systemBackground
    }

    /// The cards that make up the deck's layout. While the top card flies off it's left out, so
    /// the cards behind it move into their new places at the same time.
    var deckCards: [SwipeCardView] {
        isPromotingDeck ? Array(cardStack.dropLast()) : cardStack
    }

    /// Sideways and in the table pose (a wide, short card area on the raised half) the deck is a
    /// fan of cards, each hugging its own photo, instead of the standard full-size stack.
    var usesFannedDeckLayout: Bool {
        isLandscapeDeckActive || currentFoldPose == .table
    }

    /// With a photo on top the cards fan out to the sides, each at its own photo's size.
    /// A video on top fills the card area instead.
    var isLandscapeDeckFanned: Bool {
        guard usesFannedDeckLayout, let top = deckCards.last(where: { !$0.isHidden }) else { return false }
        return top.mediaType == .photo && (top.contentAspectRatio ?? 0) > 0
    }

    var shouldUseLandscapeDeck: Bool {
        traitCollection.horizontalSizeClass == .regular && view.bounds.width > view.bounds.height
    }

    /// Called on every layout pass; swaps the constraint sets only when the answer changes.
    func updateLandscapeDeckLayout() {
        // The main UI and the cards are built after the first appearance
        guard cardContainerView.superview != nil, !cardStack.isEmpty else { return }
        let shouldUse = shouldUseLandscapeDeck
        guard shouldUse != isLandscapeDeckActive else { return }
        // The switch can land inside an animation (the push transition, the skeleton fading out),
        // which would grow the new grips and pill from a zero frame. Lay the new layout out at once.
        UIView.performWithoutAnimation {
            if shouldUse {
                enterLandscapeDeck()
            } else {
                exitLandscapeDeck()
            }
            view.layoutIfNeeded()
        }
    }

    // MARK: - Setup

    private func setupLandscapeViewsIfNeeded() {
        guard !hasSetupLandscapeViews else { return }
        hasSetupLandscapeViews = true

        leftGrip.configure(
            primaryTitle: Strings.delete, primarySystemImage: "trash",
            primaryColor: ThemeManager.Colors.statusRed, storeTitle: Strings.store)
        leftGrip.onPrimaryTap = { [weak self] in self?.performGripAction(.left) }
        leftGrip.onStoreTap = { [weak self] in self?.performGripAction(.up) }

        rightGrip.configure(
            primaryTitle: Strings.keep, primarySystemImage: "checkmark",
            primaryColor: ThemeManager.Colors.statusGreen, storeTitle: Strings.store)
        rightGrip.onPrimaryTap = { [weak self] in self?.performGripAction(.right) }
        rightGrip.onStoreTap = { [weak self] in self?.performGripAction(.up) }

        // Under the card so a card flying off passes over them
        view.insertSubview(leftGrip, belowSubview: cardContainerView)
        view.insertSubview(rightGrip, belowSubview: cardContainerView)
        leftGrip.isHidden = true
        rightGrip.isHidden = true

        view.addLayoutGuide(binSlotGuide)

        let safeArea = view.safeAreaLayoutGuide
        let medium = GeneralConstants.EdgePadding.medium
        let bottomPadding = DuoLayout.RailPadding.bottom

        // Home's baseline: 20pt above the view's bottom, never below the safe area
        func bottomConstraints(for item: NSLayoutYAxisAnchor) -> [NSLayoutConstraint] {
            let toView = item.constraint(equalTo: view.bottomAnchor, constant: -bottomPadding)
            toView.priority = .defaultHigh
            return [toView, item.constraint(lessThanOrEqualTo: safeArea.bottomAnchor)]
        }

        let rowSplit = bottomControlsStack.trailingAnchor.constraint(equalTo: view.leadingAnchor)
        rowSplit.priority = .init(999)
        rowSplitConstraint = rowSplit
        let slotLeading = binSlotGuide.leadingAnchor.constraint(
            equalTo: bottomControlsStack.trailingAnchor, constant: medium)
        binSlotLeadingConstraint = slotLeading
        let rowEqualWidth = bottomControlsStack.widthAnchor.constraint(equalTo: binSlotGuide.widthAnchor)
        rowEqualWidthConstraint = rowEqualWidth

        landscapeConstraints = [
            leftGrip.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: medium),
            leftGrip.topAnchor.constraint(equalTo: cardContainerView.topAnchor),
            rightGrip.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -medium),
            rightGrip.topAnchor.constraint(equalTo: cardContainerView.topAnchor),

            cardContainerView.leadingAnchor.constraint(equalTo: leftGrip.trailingAnchor, constant: medium),
            cardContainerView.trailingAnchor.constraint(equalTo: rightGrip.leadingAnchor, constant: -medium),

            bottomControlsStack.leadingAnchor.constraint(equalTo: leftGrip.trailingAnchor, constant: medium),
            binSlotGuide.trailingAnchor.constraint(equalTo: rightGrip.leadingAnchor, constant: -medium),
            binSlotGuide.topAnchor.constraint(equalTo: bottomControlsStack.topAnchor),
            binSlotGuide.bottomAnchor.constraint(equalTo: bottomControlsStack.bottomAnchor),
            slotLeading,
            rowEqualWidth
        ]
        + bottomConstraints(for: leftGrip.bottomAnchor)
        + bottomConstraints(for: rightGrip.bottomAnchor)
        + bottomConstraints(for: bottomControlsStack.bottomAnchor)
    }

    // MARK: - Switching

    private func enterLandscapeDeck() {
        setupLandscapeViewsIfNeeded()
        isLandscapeDeckActive = true
        applyScreenBackground()

        duoEdges.forEach { $0.isEnabled = false }
        NSLayoutConstraint.activate(landscapeConstraints)
        cardBottomToControlsConstraint?.constant = -Layout.landscapeCardToRowGap

        // Undo + History as two equal titled pills; the bin has its own slot
        undoTrailingToFoldConstraint?.isActive = false
        undoHistoryEqualWidthConstraint?.isActive = true
        bottomControlsStack.spacing = GeneralConstants.EdgePadding.small
        bottomControlsStack.setCustomSpacing(GeneralConstants.EdgePadding.small, after: undoButton)
        bottomControlsStack.setCustomSpacing(0, after: historyButton)
        binSpacerWidthConstraint?.constant = 0
        binSpacerView.isHidden = true
        applyLandscapeUndoHistoryStyle(to: undoButton, title: Strings.undo, systemImage: "arrow.uturn.backward")
        applyLandscapeUndoHistoryStyle(to: historyButton, title: Strings.history, systemImage: "clock.arrow.circlepath")
        updateHistoryButton()

        setVideoControlsSplit(true)
        // The split controls hold the play button, so they show whenever it does
        let playButton = videoController.playPauseButton
        if !playButton.isHidden, playButton.alpha > 0 {
            videoController.controlsContainer.alpha = videoController.isPlaying ? 0.5 : 1.0
        }
        leftGrip.isHidden = false
        rightGrip.isHidden = false

        refreshCardsForLayoutChange()
        updateStats()
        lastSentBinSlot = nil
        requestBarRelayoutIfCameraOverlaps()
    }

    private func exitLandscapeDeck() {
        isLandscapeDeckActive = false
        applyScreenBackground()

        NSLayoutConstraint.deactivate(landscapeConstraints + [rowSplitConstraint].compactMap { $0 })
        duoEdges.forEach { $0.isEnabled = true }
        cardBottomToControlsConstraint?.constant = -Layout.cardToControlsGap

        bottomControlsStack.spacing = Layout.controlsSpacing
        bottomControlsStack.setCustomSpacing(Layout.controlsSpacing, after: undoButton)
        bottomControlsStack.setCustomSpacing(UIStackView.spacingUseDefault, after: historyButton)
        binSpacerView.isHidden = false
        applyStandardUndoHistoryStyle(to: undoButton, systemImage: "arrow.uturn.backward")
        applyStandardUndoHistoryStyle(to: historyButton, systemImage: "clock.arrow.circlepath")
        updateHistoryButton()

        setVideoControlsSplit(false)
        leftGrip.isHidden = true
        rightGrip.isHidden = true

        lastSentBinSlot = nil
        binController?.setBinButtonPlacement(.standard)
        refreshCardsForLayoutChange()
        DispatchQueue.main.async { [weak self] in
            self?.updateBinSpacerWidth(animated: false)
        }
    }

    func applyScreenBackground() {
        view.backgroundColor = screenBackgroundColor
        historyBadge.layer.borderColor = screenBackgroundColor.cgColor
    }

    /// Re-applies sizes, badges and stack transforms without reloading images or the video.
    func refreshCardsForLayoutChange() {
        // Same lookup as refreshStack, so cards behind processed assets get their badges too
        let indices = deckIndices(count: cardStack.count)
        for (i, card) in cardStack.enumerated() where !card.isHidden {
            let index = indices[cardStack.count - 1 - i]
            guard index < reviewAssets.count, card.assetIdentifier == reviewAssets[index].localIdentifier else { continue }
            applyBadges(to: card, reviewAsset: reviewAssets[index])
        }
        applyCardSizing()
        layoutCards()
    }

    private func applyLandscapeUndoHistoryStyle(to button: UIButton, title: String, systemImage: String) {
        // Clear the pre-iOS 26 layer styling of the round buttons
        button.backgroundColor = nil
        button.layer.cornerRadius = 0

        var config = UIButton.Configuration.filled()
        config.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        config.imagePadding = 8
        var container = AttributeContainer()
        container.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        config.attributedTitle = AttributedString(title, attributes: container)
        config.baseBackgroundColor = .cardBackground
        config.baseForegroundColor = .label
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
        button.configuration = config
    }

    // MARK: - Cards

    /// Badges inside a card. Sideways: photos get a "date · size" chip at the bottom, videos a
    /// date chip at the top plus the size badge. Otherwise the size badge as before.
    func applyBadges(to card: SwipeCardView, reviewAsset: ReviewAsset) {
        let asset = reviewAsset.asset
        let isVideo = asset.mediaType == .video
        let formattedSize = reviewAsset.fileSize.formattedBytes()

        guard isLandscapeDeckActive else {
            let showsSize = filterContext == .largeFiles || isVideo || isSizeBadgeOpen
            card.configureSize(showsSize ? formattedSize : nil)
            card.configureInfoChip(text: nil, placement: .bottomLeading)
            return
        }

        let date = asset.creationDate.map { DateFormatterManager.shared.dayMonthTime(from: $0) }
        if isVideo {
            card.configureSize(formattedSize)
            card.configureInfoChip(text: date, systemImage: "video", placement: .topLeading)
        } else {
            card.configureSize(nil)
            let text = [date, formattedSize].compactMap { $0 }.joined(separator: " · ")
            card.configureInfoChip(text: text, placement: .bottomLeading)
        }
    }

    /// Sideways with a photo on top, every card hugs its own photo's aspect ratio inside the card
    /// area (minus room for the fan). Very tall or very wide photos are clamped to 9:16…16:9 so
    /// they don't turn into thin strips; the photo is fitted inside over its blurred backdrop.
    /// The clamp is the same for the top card and the ones behind, so a card never changes shape
    /// as it comes to the top. Otherwise (a video on top, or the standard layout) the cards fill
    /// the area.
    func applyCardSizing() {
        let inset = Layout.landscapeDeckInset
        let bounds = cardContainerView.bounds.size
        let area = CGSize(
            width: bounds.width - inset.leading - inset.trailing,
            height: bounds.height - inset.top - inset.bottom)
        let topCard = deckCards.last(where: { !$0.isHidden })
        let isFanned = isLandscapeDeckFanned && area.width > 0 && area.height > 0

        func hugSize(for card: SwipeCardView) -> CGSize? {
            guard isFanned else { return nil }
            let fallback = topCard?.contentAspectRatio ?? 1
            let ratio = min(max(card.contentAspectRatio ?? fallback, Layout.landscapeCardRatioRange.lowerBound),
                            Layout.landscapeCardRatioRange.upperBound)
            guard ratio > 0 else { return nil }
            let width = floor(min(area.width, area.height * ratio))
            return CGSize(width: width, height: floor(width / ratio))
        }

        for card in deckCards {
            let id = ObjectIdentifier(card)
            guard let fill = cardFillConstraints[id], let hug = cardHugConstraints[id] else { continue }

            if let size = hugSize(for: card) {
                if hug.width.constant != size.width { hug.width.constant = size.width }
                if hug.height.constant != size.height { hug.height.constant = size.height }
                if fill.first?.isActive == true { NSLayoutConstraint.deactivate(fill) }
                if hug.width.isActive == false { NSLayoutConstraint.activate(hug.all) }
            } else {
                if hug.width.isActive { NSLayoutConstraint.deactivate(hug.all) }
                if fill.first?.isActive == false { NSLayoutConstraint.activate(fill) }
            }
        }
    }

    /// After a swipe the deck resizes to the new top card and the fan settles; call inside the
    /// swipe's animation block.
    func animateDeckToNewTopCard() {
        guard usesFannedDeckLayout else { return }
        applyCardSizing()
        cardContainerView.layoutIfNeeded()
    }

    // MARK: - Fold

    /// Splits the bottom row and the video capsules at the fold. The gap is centered on the fold
    /// line: the standard gap while fully open, the whole fold band while partly folded.
    func updateLandscapeFoldSplit() {
        guard let rowSplit = rowSplitConstraint, let slotLeading = binSlotLeadingConstraint,
              let rowEqualWidth = rowEqualWidthConstraint else { return }

        let standardGap = GeneralConstants.EdgePadding.medium
        var foldCenter: CGFloat?
        var gap = standardGap
        var foldInView: CGRect?
        if let fold = FoldRegion.splittingFold(in: view), fold.height > fold.width {
            gap = FoldRegion.activeFold(in: view).map { max(standardGap, $0.width) } ?? standardGap
            foldInView = fold
        }

        // Distances from the leading edge, so the constraints work in both layout directions
        let isLeftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
        if let fold = foldInView {
            foldCenter = isLeftToRight ? fold.midX : view.bounds.width - fold.midX
        }

        // Row: Undo + History end before the fold, the bin's slot starts after it
        var rowSplitConstant: CGFloat?
        if let center = foldCenter {
            let rowStart = isLeftToRight
                ? bottomControlsStack.frame.minX
                : view.bounds.width - bottomControlsStack.frame.maxX
            let slotEnd = isLeftToRight
                ? binSlotGuide.layoutFrame.maxX
                : view.bounds.width - binSlotGuide.layoutFrame.minX
            let constant = center - gap / 2
            let minimumWidth = GeneralConstants.ButtonSize.large * 2
            if constant - rowStart >= minimumWidth, slotEnd - (center + gap / 2) >= GeneralConstants.ButtonSize.large {
                rowSplitConstant = constant
            }
        }
        if let constant = rowSplitConstant {
            if rowEqualWidth.isActive { rowEqualWidth.isActive = false }
            if rowSplit.constant != constant { rowSplit.constant = constant }
            if !rowSplit.isActive { rowSplit.isActive = true }
            if slotLeading.constant != gap { slotLeading.constant = gap }
        } else {
            if rowSplit.isActive { rowSplit.isActive = false }
            if !rowEqualWidth.isActive { rowEqualWidth.isActive = true }
            if slotLeading.constant != standardGap { slotLeading.constant = standardGap }
        }

        updateVideoCapsuleSplit(fold: foldInView, gap: gap)
        sendBinSlotIfNeeded()
    }

    private func updateVideoCapsuleSplit(fold: CGRect?, gap: CGFloat) {
        let controls = videoController.controlsContainer
        guard let fold = fold, controls.bounds.width > 0 else {
            videoController.setSplit(leadingEnd: nil, trailingStart: nil)
            return
        }
        let foldInControls = controls.convert(fold, from: view)
        let isLeftToRight = controls.effectiveUserInterfaceLayoutDirection == .leftToRight
        let center = isLeftToRight ? foldInControls.midX : controls.bounds.width - foldInControls.midX
        let leadingEnd = center - gap / 2
        let trailingStart = center + gap / 2
        // Each capsule keeps room for its controls; otherwise two equal halves
        if leadingEnd >= Layout.videoLeadingCapsuleMinWidth,
           controls.bounds.width - trailingStart >= Layout.videoTrailingCapsuleMinWidth {
            videoController.setSplit(leadingEnd: leadingEnd, trailingStart: trailingStart)
        } else {
            videoController.setSplit(leadingEnd: nil, trailingStart: nil)
        }
    }

    /// The global bin button follows the slot after the fold. Sent again only when it moves.
    private func sendBinSlotIfNeeded() {
        guard navigationController?.topViewController === self, view.window != nil else { return }
        let slot = view.convert(binSlotGuide.layoutFrame, to: nil)
        guard slot.width > 0, slot.height > 0, slot != lastSentBinSlot else { return }
        lastSentBinSlot = slot
        binController?.setBinButtonPlacement(.slot(slot))
    }

    // MARK: - Grips

    func performGripAction(_ direction: SwipeDirection) {
        guard !isLoadingPhotos, !isAnimatingSwipe, currentIndex < reviewAssets.count,
              cardStack.last(where: { !$0.isHidden }) != nil else { return }
        completeSwipe(direction: direction)
    }

    // MARK: - Stats Pill

    /// On the inner display (regular width: upright, sideways, book or table pose) the stats show
    /// as a capsule, ReviewStatsPillView, in the hidden stats label's slot above the card. The cover
    /// display keeps the one-line label. Called on every layout pass; switches only on a change.
    func updateStatsPillVisibility() {
        guard cardContainerView.superview != nil else { return }
        let showsPill = traitCollection.horizontalSizeClass == .regular
        if showsPill { setupStatsPillIfNeeded() }
        guard hasSetupStatsPill, statsPill.isHidden == showsPill else { return }

        UIView.performWithoutAnimation {
            statsPill.alpha = statsLabel.alpha
            statsPill.isHidden = !showsPill
            statsLabel.isHidden = showsPill
            statsLabelPillHeightConstraint?.isActive = showsPill
            if showsPill { updateStats() }
            view.layoutIfNeeded()
        }
    }

    private func setupStatsPillIfNeeded() {
        guard !hasSetupStatsPill else { return }
        hasSetupStatsPill = true
        statsPill.isHidden = true
        view.addSubview(statsPill)

        // The hidden stats label keeps its slot above the card; the pill sits in it
        statsLabelPillHeightConstraint = statsLabel.heightAnchor.constraint(
            greaterThanOrEqualToConstant: ReviewStatsPillView.height)
        NSLayoutConstraint.activate([
            statsPill.centerYAnchor.constraint(equalTo: statsLabel.centerYAnchor),
            statsPill.centerXAnchor.constraint(equalTo: cardContainerView.centerXAnchor),
            statsPill.widthAnchor.constraint(lessThanOrEqualTo: cardContainerView.widthAnchor)
        ])
    }

    func updateStatsPill(_ counts: ReviewStatsPillView.Counts) {
        guard hasSetupStatsPill else { return }
        statsPill.update(with: counts, animated: !statsPill.isHidden)
    }

    // MARK: - Camera

    /// Sideways the camera sits at the top-left corner. The system moves bar buttons beside it,
    /// but only once the bar lays out again, so ask for that when the camera overlaps the bar.
    private func requestBarRelayoutIfCameraOverlaps() {
        guard #available(iOS 27.1, *), !didRequestBarRelayoutForCamera,
              let navigationBar = navigationController?.navigationBar else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self, self.isLandscapeDeckActive, self.view.window != nil else { return }
            let barFrame = navigationBar.convert(navigationBar.bounds, to: self.view)
            let cameraFrames = self.view.reservedRegions(kind: .occlusion).map(\.frame)
            guard cameraFrames.contains(where: { $0.intersects(barFrame) }) else { return }
            self.didRequestBarRelayoutForCamera = true
            navigationBar.setNeedsLayout()
            navigationBar.layoutIfNeeded()
        }
    }
}

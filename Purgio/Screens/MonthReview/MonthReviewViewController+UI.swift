//
//  MonthReviewViewController+UI.swift
//  Purgio
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import UIKit

private enum Strings {
    static let delete = CommonStrings.delete
    static let keep = NSLocalizedString("monthReview.keep", comment: "Keep swipe action label")
    static let store = NSLocalizedString("monthReview.store", comment: "Store swipe action label")
}

extension MonthReviewViewController {
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            historyBadge.layer.borderColor = screenBackgroundColor.cgColor
        }
    }
}

extension MonthReviewViewController {
    func setupSkeletonLoading() {
        let skeletonStats = SkeletonStatsView()
        skeletonStats.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skeletonStats)
        self.skeletonStatsView = skeletonStats

        let skeleton = SkeletonStackView()
        skeleton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(skeleton)
        self.skeletonStack = skeleton

        // Same frame as the card container in setupMainUI: it ends 20pt above the
        // bottom controls row, whose edges follow Home's vertical-rail padding
        let controlsAndGap = GeneralConstants.ButtonSize.large + Layout.cardToControlsGap
        let skeletonEdges = DuoEdgeConstraints(
            item: skeleton, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content,
            standardBottom: GeneralConstants.Spacer.buttonBottom + controlsAndGap,
            railBottomOffset: controlsAndGap)
        skeletonDuoEdges = [skeletonEdges]

        NSLayoutConstraint.activate(skeletonEdges.initialConstraints + [
            skeletonStats.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            skeletonStats.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            skeletonStats.widthAnchor.constraint(equalToConstant: 100),
            skeletonStats.heightAnchor.constraint(equalToConstant: 18),

            skeleton.topAnchor.constraint(equalTo: skeletonStats.bottomAnchor, constant: 16),
        ])

        skeleton.startAnimating()
        skeletonStats.startShimmerAnimation()
    }

    func hideSkeletonLoading() {
        isLoadingPhotos = false
        UIView.animate(
            withDuration: 0.3,
            animations: { [weak self] in
                self?.skeletonStack?.alpha = 0
                self?.skeletonStatsView?.alpha = 0
                self?.cardContainerView.alpha = 1
                self?.tableBaseContainerView.alpha = 1
                self?.statsLabel.alpha = 1
                self?.statsPill.alpha = 1
                self?.bottomControlsStack.alpha = 1
                self?.historyBadge.alpha = (self?.historyManager.undoCount ?? 0) > 0 ? 1.0 : 0.0
            }
        ) { [weak self] _ in
            self?.skeletonDuoEdges = []
            self?.skeletonStack?.stopAnimating()
            self?.skeletonStack?.removeFromSuperview()
            self?.skeletonStack = nil

            self?.skeletonStatsView?.stopShimmerAnimation()
            self?.skeletonStatsView?.removeFromSuperview()
            self?.skeletonStatsView = nil
        }
    }

    func setupMainUI() {
        cardContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardContainerView)
        cardContainerView.alpha = 0

        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        statsLabel.textColor = .secondaryLabel
        statsLabel.textAlignment = .center
        statsLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        statsLabel.setContentHuggingPriority(.required, for: .vertical)
        view.addSubview(statsLabel)
        statsLabel.alpha = 0

        bottomControlsStack.translatesAutoresizingMaskIntoConstraints = false
        bottomControlsStack.axis = .horizontal
        bottomControlsStack.distribution = .fill
        bottomControlsStack.alignment = .center
        bottomControlsStack.spacing = Layout.controlsSpacing

        setupButtons()

        view.addSubview(bottomControlsStack)
        bottomControlsStack.alpha = 0

        // Stats on top, card, controls at the bottom. The table-pose set (iPhone Duo) keeps the
        // stats and the card on the raised half, down to the fold; +TablePose adds the base.
        let cardBottomToControls = cardContainerView.bottomAnchor.constraint(
            equalTo: bottomControlsStack.topAnchor, constant: -Layout.cardToControlsGap)
        cardBottomToControlsConstraint = cardBottomToControls
        flatLayoutConstraints = [
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            cardContainerView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 16),
            cardBottomToControls
        ]
        let cardBottomToFold = cardContainerView.bottomAnchor.constraint(equalTo: view.topAnchor)
        cardBottomToFoldConstraint = cardBottomToFold
        tablePoseLayoutConstraints = [
            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            cardContainerView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 16),
            cardBottomToFold
        ]
        NSLayoutConstraint.activate(flatLayoutConstraints)

        // Side and bottom edges follow Home's vertical-rail padding on iPhone Duo
        let cardEdges = DuoEdgeConstraints(
            item: cardContainerView, in: view,
            standardLeading: GeneralConstants.EdgePadding.content, standardTrailing: GeneralConstants.EdgePadding.content)
        let controlsEdges = DuoEdgeConstraints(
            item: bottomControlsStack, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content,
            standardBottom: GeneralConstants.Spacer.buttonBottom)
        duoEdges = [cardEdges, controlsEdges]
        NSLayoutConstraint.activate(cardEdges.initialConstraints + controlsEdges.initialConstraints)

        NSLayoutConstraint.activate([
            statsLabel.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),

            bottomControlsStack.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),

            undoButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            historyButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            binSpacerView.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),

            historyBadge.trailingAnchor.constraint(equalTo: historyButton.trailingAnchor, constant: 4),
            historyBadge.topAnchor.constraint(equalTo: historyButton.topAnchor, constant: -4),
            historyBadge.heightAnchor.constraint(equalToConstant: 20)
        ])

        // Equal halves normally; on iPhone Duo with a vertical fold, undo ends before the fold
        // instead (see +Fold)
        let equalWidths = undoButton.widthAnchor.constraint(equalTo: historyButton.widthAnchor)
        equalWidths.isActive = true
        undoHistoryEqualWidthConstraint = equalWidths
        let undoTrailingToFold = undoButton.trailingAnchor.constraint(equalTo: view.leadingAnchor)
        undoTrailingToFold.priority = .init(999)
        undoTrailingToFoldConstraint = undoTrailingToFold

        historyBadgeWidthConstraint = historyBadge.widthAnchor.constraint(equalToConstant: 20)
        binSpacerWidthConstraint = binSpacerView.widthAnchor.constraint(equalToConstant: 0)

        if let binSpacerWidthConstraint = binSpacerWidthConstraint {
            NSLayoutConstraint.activate([
                historyBadgeWidthConstraint,
                binSpacerWidthConstraint
            ])
        }

        view.bringSubviewToFront(historyBadge)

        if filterContext == .screenshots || filterContext == .eyesClosed {
            let ring = MiniProgressRing(lineWidth: 2.5)
            ring.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                ring.widthAnchor.constraint(equalToConstant: 24),
                ring.heightAnchor.constraint(equalToConstant: 24)
            ])
            navProgressRing = ring
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: ring)
        }

        updateHistoryButton()
        historyBadge.alpha = 0
    }

    /// Icon-only round buttons, the standard look (the sideways layout adds titles, see +Landscape).
    func applyStandardUndoHistoryStyle(to button: UIButton, systemImage: String) {
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = UIImage(
                systemName: systemImage,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
            button.configuration = config
        } else {
            button.configuration = nil
            button.setTitle(nil, for: .normal)
            button.setImage(UIImage(systemName: systemImage), for: .normal)
            button.backgroundColor = .secondarySystemFill
            button.layer.cornerRadius = GeneralConstants.ButtonSize.large / 2
            button.layer.cornerCurve = .continuous
            button.clipsToBounds = true
        }
        button.tintColor = historyManager.undoCount > 0 ? .label : .systemGray
    }

    func setupButtons() {
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        applyStandardUndoHistoryStyle(to: undoButton, systemImage: "arrow.uturn.backward")
        undoButton.addTarget(self, action: #selector(handleUndo), for: .touchUpInside)
        undoButton.isEnabled = false
        undoButton.alpha = 1.0
        
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        applyStandardUndoHistoryStyle(to: historyButton, systemImage: "clock.arrow.circlepath")
        historyButton.addTarget(self, action: #selector(showUndoHistory), for: .touchUpInside)
        historyButton.isEnabled = false
        historyButton.alpha = 1.0

        historyBadge.translatesAutoresizingMaskIntoConstraints = false
        historyBadge.textAlignment = .center
        historyBadge.font = .systemFont(ofSize: 12, weight: .bold)
        historyBadge.textColor = .white
        historyBadge.backgroundColor = .systemBlue
        historyBadge.layer.cornerRadius = 10
        historyBadge.layer.cornerCurve = .continuous
        historyBadge.layer.masksToBounds = true
        historyBadge.layer.borderWidth = 2
        historyBadge.layer.borderColor = screenBackgroundColor.cgColor
        historyBadge.isHidden = true

        binSpacerView.translatesAutoresizingMaskIntoConstraints = false
        binSpacerView.backgroundColor = .clear
        binSpacerView.isUserInteractionEnabled = false
        binSpacerView.setContentHuggingPriority(.required, for: .horizontal)
        binSpacerView.setContentCompressionResistancePriority(.required, for: .horizontal)

        bottomControlsStack.addArrangedSubview(undoButton)
        bottomControlsStack.addArrangedSubview(historyButton)
        bottomControlsStack.addArrangedSubview(binSpacerView)

        view.addSubview(historyBadge)
    }

    func setupCardsAndGestures() {
        for _ in 0 ..< visibleCardCount {
            let card = SwipeCardView(frame: .zero)
            card.translatesAutoresizingMaskIntoConstraints = false
            card.onPlaceholderTap = {
//                [weak self] in
//                self?.openSettingsTab()
            }
            card.onICloudBadgeTap = { [weak self] in
                self?.showICloudBadgeTapSheet()
            }
            card.onEnableInternetTap = { [weak self] in
                guard let self = self else { return }
                self.settingsStore.allowInternetAccess = true
                self.haptics.impact(intensity: .medium)
                self.showInternetEnabledConfirmation()
                self.refreshStack()
            }
            card.onSkipTap = { [weak self] in
                guard let self = self else { return }
                self.currentIndex += 1
                self.advanceToFirstUnprocessedIndex()
                self.refreshStack()
            }
            cardStack.append(card)
            cardContainerView.addSubview(card)
        }

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        cardContainerView.addGestureRecognizer(panGesture)

        // Fill the card area; sideways on iPhone Duo a photo hugs its aspect ratio instead (+Landscape)
        for card in cardStack {
            let fill = [
                card.topAnchor.constraint(equalTo: cardContainerView.topAnchor),
                card.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor),
                card.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(fill)
            cardFillConstraints[ObjectIdentifier(card)] = fill
            cardHugConstraints[ObjectIdentifier(card)] = CardHugConstraints(card: card, in: cardContainerView)
        }

        setupEdgeGradients()
        setupVideoControls()
    }

    func setupEdgeGradients() {
        leftGradient.translatesAutoresizingMaskIntoConstraints = false
        leftGradient.alpha = 0
        leftGradient.isUserInteractionEnabled = false
        leftGradient.startPoint = CGPoint(x: 0, y: 0.5)
        leftGradient.endPoint = CGPoint(x: 1, y: 0.5)
        leftGradient.colors = [
            UIColor.red.withAlphaComponent(0.6),
            UIColor.red.withAlphaComponent(0.0)
        ]
        view.insertSubview(leftGradient, belowSubview: statsLabel)

        rightGradient.translatesAutoresizingMaskIntoConstraints = false
        rightGradient.alpha = 0
        rightGradient.isUserInteractionEnabled = false
        rightGradient.startPoint = CGPoint(x: 1, y: 0.5)
        rightGradient.endPoint = CGPoint(x: 0, y: 0.5)
        rightGradient.colors = [
            UIColor.green.withAlphaComponent(0.6),
            UIColor.green.withAlphaComponent(0.0)
        ]
        view.insertSubview(rightGradient, belowSubview: statsLabel)

        topGradient.translatesAutoresizingMaskIntoConstraints = false
        topGradient.alpha = 0
        topGradient.isUserInteractionEnabled = false
        topGradient.startPoint = CGPoint(x: 0.5, y: 0)
        topGradient.endPoint = CGPoint(x: 0.5, y: 1)
        topGradient.colors = [
            UIColor.systemYellow.withAlphaComponent(0.6),
            UIColor.systemYellow.withAlphaComponent(0.0)
        ]
        view.insertSubview(topGradient, belowSubview: statsLabel)

        NSLayoutConstraint.activate([
            leftGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            leftGradient.topAnchor.constraint(equalTo: view.topAnchor),
            leftGradient.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            leftGradient.widthAnchor.constraint(equalToConstant: 120),

            rightGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rightGradient.topAnchor.constraint(equalTo: view.topAnchor),
            rightGradient.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            rightGradient.widthAnchor.constraint(equalToConstant: 120),

            topGradient.topAnchor.constraint(equalTo: view.topAnchor),
            topGradient.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topGradient.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topGradient.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    func layoutCards() {
        let cards = deckCards
        for (index, card) in cards.enumerated() {
            cardContainerView.bringSubviewToFront(card)

            let reverseIndex = cards.count - 1 - index
            card.transform = stackTransform(reverseIndex: reverseIndex)
            card.alpha = stackAlpha(reverseIndex: reverseIndex)
            card.showsInfoChip = reverseIndex == 0
        }
        // The card flying off stays above the deck moving in behind it
        if isPromotingDeck, let flyingCard = cardStack.last {
            cardContainerView.bringSubviewToFront(flyingCard)
        }

        // In the split layout the play button lives inside the controls
        if videoController.playPauseButton.superview === cardContainerView {
            cardContainerView.bringSubviewToFront(videoController.playPauseButton)
        }
        cardContainerView.bringSubviewToFront(videoController.controlsContainer)
        updateTablePosePreview()
    }

    /// Where a card sits in the stack: 0 is the top card.
    func stackTransform(reverseIndex: Int) -> CGAffineTransform {
        let level = CGFloat(reverseIndex)
        if usesFannedDeckLayout {
            guard reverseIndex > 0 else { return .identity }
            // Behind a photo the next cards fan out to alternate sides, like a hand of prints.
            // A video fills the card area, so there they stay tucked in behind it.
            guard isLandscapeDeckFanned else {
                let scale = 1.0 - level * 0.04
                return CGAffineTransform(scaleX: scale, y: scale)
            }
            let side: CGFloat = reverseIndex.isMultiple(of: 2) ? 1 : -1
            // A wide card's ends swing far up and down when turned, so wide photos turn less
            // and peek out sideways instead (3.5° up to 3:2, about 1.6° for a panorama)
            let cards = deckCards
            let stackIndex = cards.count - 1 - reverseIndex
            let ownRatio = cards.indices.contains(stackIndex) ? cards[stackIndex].contentAspectRatio : nil
            let ratio = min(ownRatio ?? 1, Layout.landscapeCardRatioRange.upperBound)
            let degrees = side * 3.5 * min(1, 1.5 / max(ratio, 0.1))
            let offset = side * (8 + level * 8)
            let scale = 1.0 - level * 0.035
            return CGAffineTransform(translationX: offset, y: 0)
                .rotated(by: degrees * .pi / 180)
                .scaledBy(x: scale, y: scale)
        }
        let scale = 1.0 - (level * 0.05)
        return CGAffineTransform(scaleX: scale, y: scale).translatedBy(x: 0, y: level * 10)
    }

    func stackAlpha(reverseIndex: Int) -> CGFloat {
        // Opaque, so the fanned prints don't show through each other
        return 1.0
    }
}

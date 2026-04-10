//
//  MonthReviewViewController+UI.swift
//  Secure Photo Cleaner
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
            historyBadge.layer.borderColor = UIColor.systemBackground.cgColor
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

        NSLayoutConstraint.activate([
            skeletonStats.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            skeletonStats.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skeletonStats.widthAnchor.constraint(equalToConstant: 100),
            skeletonStats.heightAnchor.constraint(equalToConstant: 18),

            skeleton.topAnchor.constraint(equalTo: skeletonStats.bottomAnchor, constant: 16),
            skeleton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            skeleton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            skeleton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
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
                self?.statsLabel.alpha = 1
                self?.bottomControlsStack.alpha = 1
                self?.historyBadge.alpha = (self?.historyManager.undoCount ?? 0) > 0 ? 1.0 : 0.0
            }
        ) { [weak self] _ in
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
        bottomControlsStack.spacing = 16

        setupButtons()

        view.addSubview(bottomControlsStack)
        bottomControlsStack.alpha = 0

        NSLayoutConstraint.activate([
            cardContainerView.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 16),
            cardContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cardContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cardContainerView.bottomAnchor.constraint(equalTo: bottomControlsStack.topAnchor, constant: -20),

            statsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            statsLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            bottomControlsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomControlsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomControlsStack.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -GeneralConstants.Spacer.buttonBottom),
            bottomControlsStack.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),

            undoButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            historyButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            binSpacerView.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),

            undoButton.widthAnchor.constraint(equalTo: historyButton.widthAnchor),

            historyBadge.trailingAnchor.constraint(equalTo: historyButton.trailingAnchor, constant: 4),
            historyBadge.topAnchor.constraint(equalTo: historyButton.topAnchor, constant: -4),
            historyBadge.heightAnchor.constraint(equalToConstant: 20)
        ])

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

    func setupButtons() {
        undoButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = UIImage(
                systemName: "arrow.uturn.backward",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
            undoButton.configuration = config
            undoButton.tintColor = .label
        } else {
            undoButton.setImage(UIImage(systemName: "arrow.uturn.backward"), for: .normal)
            undoButton.tintColor = .label
            undoButton.backgroundColor = .secondarySystemFill
            undoButton.layer.cornerRadius = GeneralConstants.ButtonSize.large / 2
            undoButton.clipsToBounds = true
        }
        undoButton.addTarget(self, action: #selector(handleUndo), for: .touchUpInside)
        undoButton.isEnabled = false
        undoButton.alpha = 1.0
        
        historyButton.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.image = UIImage(
                systemName: "clock.arrow.circlepath",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14)
            historyButton.configuration = config
            historyButton.tintColor = .label
        } else {
            historyButton.setImage(UIImage(systemName: "clock.arrow.circlepath"), for: .normal)
            historyButton.tintColor = .label
            historyButton.backgroundColor = .secondarySystemFill
            historyButton.layer.cornerRadius = GeneralConstants.ButtonSize.large / 2
            historyButton.clipsToBounds = true
        }
        historyButton.addTarget(self, action: #selector(showUndoHistory), for: .touchUpInside)
        historyButton.isEnabled = false
        historyButton.alpha = 1.0

        historyBadge.translatesAutoresizingMaskIntoConstraints = false
        historyBadge.textAlignment = .center
        historyBadge.font = .systemFont(ofSize: 12, weight: .bold)
        historyBadge.textColor = .white
        historyBadge.backgroundColor = .systemBlue
        historyBadge.layer.cornerRadius = 10
        historyBadge.layer.masksToBounds = true
        historyBadge.layer.borderWidth = 2
        historyBadge.layer.borderColor = UIColor.systemBackground.cgColor
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

        for card in cardStack {
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: cardContainerView.topAnchor),
                card.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor),
                card.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor),
                card.bottomAnchor.constraint(equalTo: cardContainerView.bottomAnchor)
            ])
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
        for (index, card) in cardStack.enumerated() {
            cardContainerView.bringSubviewToFront(card)

            let reverseIndex = CGFloat(cardStack.count - 1 - index)

            let scale = 1.0 - (reverseIndex * 0.05)
            let translationY = reverseIndex * 10

            card.transform = CGAffineTransform(scaleX: scale, y: scale)
                .translatedBy(x: 0, y: translationY)
            card.alpha = 1.0
        }

        cardContainerView.bringSubviewToFront(videoController.playPauseButton)
        cardContainerView.bringSubviewToFront(videoController.controlsContainer)
    }
}

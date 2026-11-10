//
//  SettingsSupportCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// Settings' Support section as one card for the iPhone Duo split layouts: the support text,
/// the ink "Leave a Tip" button, and Rate / Feedback side by side under it. A link title that
/// doesn't fit half the card wraps to a second line.
final class SettingsSupportCardView: UIView {

    var onTip: (() -> Void)?
    var onRate: (() -> Void)?
    var onFeedback: (() -> Void)?

    private enum Layout {
        static let verticalPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 18
        static let iconSize: CGFloat = 24
        static let linkCornerRadius: CGFloat = 12
    }

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        imageView.image = UIImage(systemName: "heart.fill", withConfiguration: symbolConfig)
        imageView.tintColor = .tipJarRed100
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()

    private let titleRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()

    /// Ink button (board S3t): `.label` fill, so black in light and white in dark, with a red heart
    private let tipButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .label
        config.baseForegroundColor = .systemBackground
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        config.image = UIImage(systemName: "heart.fill", withConfiguration: symbolConfig)?
            .withTintColor(.tipJarRed100, renderingMode: .alwaysOriginal)
        config.imagePadding = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = .systemFont(ofSize: 15, weight: .semibold)
            return updated
        }
        config.background.cornerRadius = Layout.linkCornerRadius
        config.cornerStyle = .fixed
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        button.configuration = config
        return button
    }()

    private let rateButton = SettingsSupportCardView.makeLinkButton(iconName: "star", iconColor: .systemYellow)
    private let feedbackButton = SettingsSupportCardView.makeLinkButton(iconName: "envelope", iconColor: .systemBlue)

    private let linksStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = GeneralConstants.EdgePadding.small
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(title: String, message: String, tipTitle: String, rateTitle: String, feedbackTitle: String) {
        titleLabel.text = title
        messageLabel.text = message
        tipButton.configuration?.title = tipTitle
        rateButton.configuration?.title = rateTitle
        feedbackButton.configuration?.title = feedbackTitle
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLinkCorners()
    }

    /// A link button's bottom corner that sits in the card's bottom corner is concentric with
    /// the card's corner there (its radius minus the padding, at least the standard 12), so it
    /// widens with the card when the card follows the device corner
    /// (`updateCardCorners(followingDeviceCorner:)`). Every other corner stays 12.
    /// `containerConcentric` would resolve against the window, not the card, so the radius is
    /// computed from the card's own effective radius; reading it here re-runs this on changes.
    private func updateLinkCorners() {
        guard #available(iOS 26.0, *), bounds.width > 0 else { return }
        // The buttons' frames are only final once the stacks are laid out
        contentStack.layoutIfNeeded()
        let standard = Layout.linkCornerRadius
        let inset = min(Layout.horizontalPadding, Layout.verticalPadding)
        let outerLeft = max(standard, effectiveRadius(corner: .bottomLeft) - inset)
        let outerRight = max(standard, effectiveRadius(corner: .bottomRight) - inset)
        let tolerance: CGFloat = 1
        for button in [rateButton, feedbackButton] {
            let frame = button.convert(button.bounds, to: self)
            let onBottom = abs(bounds.height - Layout.verticalPadding - frame.maxY) <= tolerance
            let onLeft = onBottom && abs(frame.minX - Layout.horizontalPadding) <= tolerance
            let onRight = onBottom && abs(bounds.width - Layout.horizontalPadding - frame.maxX) <= tolerance
            button.cornerConfiguration = .corners(
                topLeftRadius: .fixed(standard),
                topRightRadius: .fixed(standard),
                bottomLeftRadius: .fixed(onLeft ? outerLeft : standard),
                bottomRightRadius: .fixed(onRight ? outerRight : standard))
        }
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false

        titleRow.addArrangedSubview(iconView)
        titleRow.addArrangedSubview(titleLabel)

        linksStack.addArrangedSubview(rateButton)
        linksStack.addArrangedSubview(feedbackButton)

        contentStack.addArrangedSubview(titleRow)
        contentStack.addArrangedSubview(messageLabel)
        contentStack.addArrangedSubview(tipButton)
        contentStack.addArrangedSubview(linksStack)
        contentStack.setCustomSpacing(6, after: titleRow)
        contentStack.setCustomSpacing(GeneralConstants.EdgePadding.small, after: tipButton)
        addSubview(contentStack)

        tipButton.addTarget(self, action: #selector(tipTapped), for: .touchUpInside)
        rateButton.addTarget(self, action: #selector(rateTapped), for: .touchUpInside)
        feedbackButton.addTarget(self, action: #selector(feedbackTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Layout.iconSize),
            tipButton.heightAnchor.constraint(greaterThanOrEqualToConstant: GeneralConstants.ButtonSize.medium),
            rateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: GeneralConstants.ButtonSize.medium),
            feedbackButton.heightAnchor.constraint(greaterThanOrEqualToConstant: GeneralConstants.ButtonSize.medium),

            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            // The card may grow taller than its content (ending level with a neighbor in a row);
            // the content then stays at the top instead of stretching
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Layout.verticalPadding)
        ])
        let hugContent = contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding)
        hugContent.priority = .defaultLow
        hugContent.isActive = true
    }

    private static func makeLinkButton(iconName: String, iconColor: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .tertiarySystemFill
        config.baseForegroundColor = .label
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        config.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)?
            .withTintColor(iconColor, renderingMode: .alwaysOriginal)
        config.imagePadding = 6
        // Always side by side: a title that doesn't fit half the card (Turkish, the upright
        // column) wraps to a second line, and both buttons keep the same height
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = .systemFont(ofSize: 15, weight: .semibold)
            return updated
        }
        config.cornerStyle = .fixed
        if #available(iOS 26.0, *) {
            // The view's corner configuration shapes it (updateLinkCorners), so the
            // background fills the bounds and the view clips it
            config.background.cornerRadius = 0
            button.clipsToBounds = true
        } else {
            config.background.cornerRadius = Layout.linkCornerRadius
        }
        // Tight sides so both titles fit half the card in Turkish too, keeping them side by side
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 8, bottom: 10, trailing: 8)
        button.configuration = config
        return button
    }

    // MARK: - Actions

    @objc private func tipTapped() {
        onTip?()
    }

    @objc private func rateTapped() {
        onRate?()
    }

    @objc private func feedbackTapped() {
        onFeedback?()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let card = SettingsSupportCardView()
    card.configure(
        title: NSLocalizedString("settings.supportTitle", comment: ""),
        message: NSLocalizedString("settings.supportText", comment: ""),
        tipTitle: NSLocalizedString("settings.supportButton", comment: ""),
        rateTitle: NSLocalizedString("settings.rateAppTitle", comment: ""),
        feedbackTitle: NSLocalizedString("settings.giveFeedbackTitle", comment: ""))

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(card)
    NSLayoutConstraint.activate([
        card.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
        card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
    ])
    return container
}
#endif

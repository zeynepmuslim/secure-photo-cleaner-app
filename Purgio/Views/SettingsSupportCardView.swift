//
//  SettingsSupportCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// Settings' Support section as one card: the support text, the ink "Leave a Tip" button, and
/// Rate / Feedback under it, side by side in the split layouts (a title that doesn't fit half
/// the card wraps to a second line) or stacked in the single column (`setLinksStacked`).
final class SettingsSupportCardView: UIView {

    var onTip: (() -> Void)?
    var onRate: (() -> Void)?
    var onFeedback: (() -> Void)?

    private enum Layout {
        static let verticalPadding: CGFloat = 16
        static let horizontalPadding: CGFloat = 18
        static let iconSize: CGFloat = 24
        static let linkCornerRadius: CGFloat = 12
        static let linkBorderWidth: CGFloat = 1
        static let linkSideInset: CGFloat = 8
        static let linkFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
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

    // Rate and Feedback are equal outline buttons under the ink tip button: no fill, a hairline
    // border and the title color, only their icons colored (a yellow star, a blue envelope)
    private let rateButton = SettingsSupportCardView.makeLinkButton(
        iconName: "star.fill", iconColor: .systemYellow)
    private let feedbackButton = SettingsSupportCardView.makeLinkButton(
        iconName: "envelope", iconColor: .systemBlue)

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

    /// The single column (iPhones, the cover display) stacks Rate and Feedback under the tip
    /// button, one full-width row each, so neither title has to wrap; the split layouts keep
    /// them side by side to save height
    func setLinksStacked(_ stacked: Bool) {
        let axis: NSLayoutConstraint.Axis = stacked ? .vertical : .horizontal
        guard linksStack.axis != axis else { return }
        linksStack.axis = axis
        linksStack.distribution = stacked ? .fill : .fillEqually
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateLinkInsets()
        updateLinkCorners()
    }

    /// A title that wraps takes the button's whole width, so its icon sits at the leading edge
    /// with the lines off-center. The side insets grow by the wrapped lines' unused width, split
    /// evenly, so the icon and title sit centered together; the lines wrap the same, so the
    /// button's height doesn't change
    private func updateLinkInsets() {
        for button in [rateButton, feedbackButton] {
            guard var config = button.configuration, let title = config.title,
                  button.bounds.width > 0 else { continue }
            let iconWidth = (config.image?.size.width ?? 0) + config.imagePadding
            let available = button.bounds.width - 2 * Layout.linkSideInset - iconWidth
            guard available > 0 else { continue }
            let used = (title as NSString).boundingRect(
                with: CGSize(width: available, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: Layout.linkFont],
                context: nil).width
            // A point of slack so the label doesn't wrap one word earlier than measured
            let side = Layout.linkSideInset + max(0, floor((available - ceil(used) - 1) / 2))
            guard config.contentInsets.leading != side else { continue }
            config.contentInsets.leading = side
            config.contentInsets.trailing = side
            button.configuration = config
        }
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

    /// The iOS 26 border is the layer's, so its `CGColor` is resolved per appearance
    private func updateLinkBorderColor() {
        let color = UIColor.separator.resolvedColor(with: traitCollection).cgColor
        rateButton.layer.borderColor = color
        feedbackButton.layer.borderColor = color
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

        if #available(iOS 26.0, *) {
            updateLinkBorderColor()
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: Self, _: UITraitCollection) in
                self.updateLinkBorderColor()
            }
        }

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
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .label
        // A dynamic color, resolved against the button's appearance
        config.imageColorTransformer = UIConfigurationColorTransformer { _ in iconColor }
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        config.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        config.imagePadding = 6
        // Side by side, a title that doesn't fit half the card (Turkish, the upright column)
        // wraps to a second line, its lines centered, and both buttons keep the same height
        config.titleLineBreakMode = .byWordWrapping
        config.titleAlignment = .center
        let centered = NSMutableParagraphStyle()
        centered.alignment = .center
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var updated = attributes
            updated.font = Layout.linkFont
            updated.paragraphStyle = centered
            return updated
        }
        config.cornerStyle = .fixed
        if #available(iOS 26.0, *) {
            // The view's corner configuration shapes it (updateLinkCorners), so the
            // background fills the bounds, the view clips it and the layer draws the border
            // along those corners (a background stroke would be cut off at them)
            config.background.cornerRadius = 0
            button.clipsToBounds = true
            button.layer.borderWidth = Layout.linkBorderWidth
        } else {
            config.background.cornerRadius = Layout.linkCornerRadius
            config.background.strokeColor = .separator
            config.background.strokeWidth = Layout.linkBorderWidth
        }
        // Tight sides so both titles fit half the card in Turkish too when side by side
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 10, leading: Layout.linkSideInset, bottom: 10, trailing: Layout.linkSideInset)
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

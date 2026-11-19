//
//  DashboardCard.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import UIKit

class DashboardCard: UIView {

    /// From this height the card uses its roomy layout (Home fits its rows around it)
    static let roomyMinimumHeight: CGFloat = 260

    /// How the card arranges itself for the room it gets (board D1 and the Duo's upright base)
    private enum SizeVariant {
        /// Icon beside the title, the note and a small button (phones, short slots)
        case regular
        /// The icon over centered texts and the button, all one centered group
        case roomy
        /// Wide but short: the icon beside the texts, the button under them, all one centered group
        case wideShort
    }

    private enum Layout {
        static let roomyMinimumHeight = DashboardCard.roomyMinimumHeight
        static let wideShortMinimumWidth: CGFloat = 500
        static let regularButtonHeight: CGFloat = 36
        static let roomyButtonFontSize: CGFloat = 16
        /// The roomy buttons hug their title with this much on each side
        static let roomyButtonSideInset: CGFloat = 28

        enum Roomy {
            static let padding: CGFloat = 24
            static let iconBox: CGFloat = 56
            static let iconPointSize: CGFloat = 44
            static let titleSize: CGFloat = 22
            static let subtitleSize: CGFloat = 15
            static let gap: CGFloat = 14
            static let textSpacing: CGFloat = 6
            static let groupToButton: CGFloat = 20
            static let buttonHeight: CGFloat = 50
        }

        enum WideShort {
            static let verticalPadding: CGFloat = 16
            static let sidePadding: CGFloat = 18
            static let iconBox: CGFloat = 44
            static let iconPointSize: CGFloat = 36
            static let titleSize: CGFloat = 20
            static let subtitleSize: CGFloat = 14
            static let gap: CGFloat = 16
            static let textSpacing: CGFloat = 4
            static let buttonHeight: CGFloat = 48
            static let groupToButton: CGFloat = 12
        }
    }

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .small
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let alignmentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .equalSpacing
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: Roomy variants

    private let roomyTextStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The icon and the texts
    private let heroGroup: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// The icon and texts over the button, centered in the card as one group
    private let roomyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.isHidden = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var appliedVariant: SizeVariant = .regular
    private var roomyTopConstraint: NSLayoutConstraint?
    private var roomyLeadingConstraint: NSLayoutConstraint?
    private var roomyTrailingConstraint: NSLayoutConstraint?
    private var roomyBottomConstraint: NSLayoutConstraint?
    private var buttonHeightConstraint: NSLayoutConstraint?
    /// Roomy variants: the button is at least as wide as the icon and texts above it
    private var buttonMinimumWidthConstraint: NSLayoutConstraint?
    /// The regular button's insets, restored when the card goes back to its regular layout
    private var regularButtonInsets: NSDirectionalEdgeInsets?

    private var buttonAction: (() -> Void)?
    private var currentContent: DashboardCardContent?

    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let variant: SizeVariant
        if bounds.height >= Layout.roomyMinimumHeight {
            variant = .roomy
        } else if bounds.width > Layout.wideShortMinimumWidth {
            variant = .wideShort
        } else {
            variant = .regular
        }
        if variant != appliedVariant {
            apply(variant)
            setNeedsLayout()
        }
        if variant == .regular {
            applySizeVariant()
        }
    }

    /// Moves the icon, the texts and the button between the regular stacks and the roomy one
    private func apply(_ variant: SizeVariant) {
        appliedVariant = variant

        guard variant != .regular else {
            headerStack.insertArrangedSubview(iconView, at: 0)
            headerStack.addArrangedSubview(titleLabel)
            contentStack.insertArrangedSubview(subtitleLabel, at: 1)
            contentStack.addArrangedSubview(actionButton)
            iconView.contentMode = .scaleAspectFit
            titleLabel.textAlignment = .natural
            subtitleLabel.textAlignment = .left
            subtitleLabel.numberOfLines = 0
            subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
            buttonHeightConstraint?.constant = Layout.regularButtonHeight
            buttonMinimumWidthConstraint?.isActive = false
            titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            subtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            setButtonStyle(font: nil, sideInset: nil)
            roomyStack.isHidden = true
            alignmentStack.isHidden = false
            return
        }

        let isRoomy = variant == .roomy
        let iconBox = isRoomy ? Layout.Roomy.iconBox : Layout.WideShort.iconBox
        heroGroup.insertArrangedSubview(iconView, at: 0)
        let iconPointSize = isRoomy ? Layout.Roomy.iconPointSize : Layout.WideShort.iconPointSize
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .medium)
        // A plain symbol at its point size, centered in its box (never on a background)
        iconView.contentMode = .center
        iconWidthConstraint?.constant = iconBox
        iconHeightConstraint?.constant = iconBox

        roomyTextStack.addArrangedSubview(titleLabel)
        roomyTextStack.addArrangedSubview(subtitleLabel)
        roomyTextStack.spacing = isRoomy ? Layout.Roomy.textSpacing : Layout.WideShort.textSpacing
        roomyTextStack.alignment = isRoomy ? .center : .leading
        roomyStack.addArrangedSubview(actionButton)
        // Both are in the roomy stack now, so the constraint has a common ancestor
        if buttonMinimumWidthConstraint == nil {
            buttonMinimumWidthConstraint = actionButton.widthAnchor.constraint(
                greaterThanOrEqualTo: heroGroup.widthAnchor)
        }
        buttonMinimumWidthConstraint?.isActive = true
        // The button widens to the texts; the texts only shrink when the card itself is too narrow
        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)

        heroGroup.axis = isRoomy ? .vertical : .horizontal
        heroGroup.alignment = .center
        heroGroup.spacing = isRoomy ? Layout.Roomy.gap : Layout.WideShort.gap

        let alignment: NSTextAlignment = isRoomy ? .center : .natural
        titleLabel.textAlignment = alignment
        subtitleLabel.textAlignment = alignment
        titleLabel.font = ThemeManager.Fonts.titleFont(
            size: isRoomy ? Layout.Roomy.titleSize : Layout.WideShort.titleSize, weight: .bold)
        subtitleLabel.font = .systemFont(
            ofSize: isRoomy ? Layout.Roomy.subtitleSize : Layout.WideShort.subtitleSize, weight: .regular)
        subtitleLabel.numberOfLines = isRoomy ? 3 : 2

        let vertical = isRoomy ? Layout.Roomy.padding : Layout.WideShort.verticalPadding
        let side = isRoomy ? Layout.Roomy.padding : Layout.WideShort.sidePadding
        roomyTopConstraint?.constant = vertical
        roomyBottomConstraint?.constant = -vertical
        roomyLeadingConstraint?.constant = side
        roomyTrailingConstraint?.constant = -side
        roomyStack.spacing = isRoomy ? Layout.Roomy.groupToButton : Layout.WideShort.groupToButton
        buttonHeightConstraint?.constant = isRoomy ? Layout.Roomy.buttonHeight : Layout.WideShort.buttonHeight
        setButtonStyle(
            font: .systemFont(ofSize: Layout.roomyButtonFontSize, weight: .semibold),
            sideInset: Layout.roomyButtonSideInset)

        alignmentStack.isHidden = true
        roomyStack.isHidden = false
    }

    /// nil restores the button's standard title font and insets
    private func setButtonStyle(font: UIFont?, sideInset: CGFloat?) {
        guard var config = actionButton.configuration else { return }
        if regularButtonInsets == nil {
            regularButtonInsets = config.contentInsets
        }
        if let sideInset {
            config.contentInsets = NSDirectionalEdgeInsets(
                top: 0, leading: sideInset, bottom: 0, trailing: sideInset)
        } else if let regularButtonInsets {
            config.contentInsets = regularButtonInsets
        }
        if let font {
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = font
                return outgoing
            }
        } else {
            config.titleTextAttributesTransformer = nil
        }
        actionButton.configuration = config
    }

    private func applySizeVariant() {
        let isSmallScreen = bounds.width < GeneralConstants.CompactContentWidth.fullWidthCard

        let iconPointSize: CGFloat = isSmallScreen ? 20 : 24
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .medium)

        let titleSize: CGFloat = isSmallScreen ? 15 : 18
        titleLabel.font = ThemeManager.Fonts.titleFont(size: titleSize, weight: .semibold)

        headerStack.spacing = isSmallScreen ? 10 : 12

        let iconDimension: CGFloat = isSmallScreen ? 24 : 28
        iconWidthConstraint?.constant = iconDimension
        iconHeightConstraint?.constant = iconDimension

        let horizontalPadding: CGFloat = isSmallScreen ? 14 : 18
        leadingConstraint?.constant = horizontalPadding
        trailingConstraint?.constant = -horizontalPadding
    }
    
    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 0
        layer.borderColor = UIColor.separator.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(titleLabel)

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(actionButton)

        alignmentStack.addArrangedSubview(UIView.flexibleSpacer())
        alignmentStack.addArrangedSubview(contentStack)
        alignmentStack.addArrangedSubview(UIView.flexibleSpacer())

        addSubview(alignmentStack)

        heroGroup.addArrangedSubview(roomyTextStack)
        roomyStack.addArrangedSubview(heroGroup)
        addSubview(roomyStack)

        setupConstraint()
        applySizeVariant()
    }

    private func setupConstraint() {
        let iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 28)
        let iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 28)
        let leadingConstraint = alignmentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18)
        let trailingConstraint = alignmentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18)
        self.iconWidthConstraint = iconWidthConstraint
        self.iconHeightConstraint = iconHeightConstraint
        self.leadingConstraint = leadingConstraint
        self.trailingConstraint = trailingConstraint

        // The group sits in the card's vertical center and only touches the padding when full
        let roomyTop = roomyStack.topAnchor.constraint(
            greaterThanOrEqualTo: topAnchor, constant: Layout.Roomy.padding)
        let roomyLeading = roomyStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.Roomy.padding)
        let roomyTrailing = roomyStack.trailingAnchor.constraint(
            equalTo: trailingAnchor, constant: -Layout.Roomy.padding)
        let roomyBottom = roomyStack.bottomAnchor.constraint(
            lessThanOrEqualTo: bottomAnchor, constant: -Layout.Roomy.padding)
        let buttonHeight = actionButton.heightAnchor.constraint(equalToConstant: Layout.regularButtonHeight)
        roomyTopConstraint = roomyTop
        roomyLeadingConstraint = roomyLeading
        roomyTrailingConstraint = roomyTrailing
        roomyBottomConstraint = roomyBottom
        buttonHeightConstraint = buttonHeight

        NSLayoutConstraint.activate([
            iconWidthConstraint,
            iconHeightConstraint,

            alignmentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            leadingConstraint,
            trailingConstraint,
            alignmentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            buttonHeight,

            roomyTop,
            roomyLeading,
            roomyTrailing,
            roomyBottom,
            roomyStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(with content: DashboardCardContent, actionHandler: @escaping (DashboardCardAction) -> Void) {
        currentContent = content

        iconView.image = UIImage(systemName: content.icon)
        iconView.tintColor = .blue100
        titleLabel.text = content.title
        subtitleLabel.text = content.subtitle
        actionButton.setTitle(content.action.buttonTitle, for: .normal)

        var config = actionButton.configuration
        config?.baseBackgroundColor = .blue100
        actionButton.configuration = config

        self.buttonAction = { [weak self] in
            guard let self = self, let content = self.currentContent else { return }
            actionHandler(content.action)
        }
    }
    
    func updateContent(_ content: DashboardCardContent, actionHandler: @escaping (DashboardCardAction) -> Void) {
        UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
            self.configure(with: content, actionHandler: actionHandler)
        }
    }

    @objc private func buttonTapped() {
        buttonAction?()
    }
}

// MARK: - Previews
#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct DashboardCardPreview: UIViewRepresentable {
        let configure: (DashboardCard) -> Void

        func makeUIView(context: Context) -> DashboardCard {
            let view = DashboardCard()
            configure(view)
            return view
        }

        func updateUIView(_ uiView: DashboardCard, context: Context) {
            configure(uiView)
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: DashboardCard, context: Context) -> CGSize? {
            return CGSize(width: proposal.width ?? 360, height: 190)
        }
    }

    @available(iOS 17.0, *)
    #Preview("Motivation Card", traits: .sizeThatFitsLayout) {
        DashboardCardPreview { view in
            let content = DashboardCardContent.motivation(
                title: NSLocalizedString("motivation.newMemories", comment: ""),
                subtitle: NSLocalizedString("suggestion.oldestFiles", comment: ""),
                action: .viewOldestYear(year: "2017")
            )
            view.configure(with: content) { _ in }
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Analytics Card", traits: .sizeThatFitsLayout) {
        DashboardCardPreview { view in
            let content = DashboardCardContent.analytics(
                title: NSLocalizedString("dashboard.yourImpact", comment: ""),
                subtitle: NSLocalizedString("analytics.itemsCleaned", comment: "")
            )
            view.configure(with: content) { _ in }
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Resume Card", traits: .sizeThatFitsLayout) {
        DashboardCardPreview { view in
            let content = DashboardCardContent.motivation(
                title: NSLocalizedString("dashboard.continueWhereLeftOff", comment: ""),
                subtitle: NSLocalizedString("dashboard.continueMonth", comment: ""),
                action: .resumeMonth(monthKey: "2024-10", mediaType: .image)
            )
            view.configure(with: content) { _ in }
        }
        .padding()
    }

#endif

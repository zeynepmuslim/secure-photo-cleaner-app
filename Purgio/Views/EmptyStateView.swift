//
//  EmptyStateView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import UIKit

/// The app's empty and finished states. Two shapes:
/// - `configure(icon:iconColor:title:message:…)`: a small centered stack (MonthsList).
/// - `configure(hero:title:message:accessory:…)`: the board layout "Empty & finished states":
///   a hero (the done stamp, or a thin symbol), the title and the message centered above an
///   actions column that rests on Home's baseline: an optional accessory, the ink primary
///   button (with an optional slot beside it for the global bin) and a quiet secondary.
///   Hosts pin the view's sides to the safe area and its top and bottom to their view, and
///   pass the tab rail's edge on every layout pass (`update(railEdge:)`).
final class EmptyStateView: UIView {

    /// What sits above the title in the board layout.
    enum Hero: Equatable {
        /// The green done stamp, the same one the month hub shows (`ReviewCapsuleView`).
        case stamp
        /// A thin SF Symbol in gray, for states with nothing to finish.
        case symbol(String)
    }

    private enum Layout {
        static let stampSize = CGSize(width: 40, height: 120)
        static let compactStampSize = CGSize(width: 32, height: 96)
        /// The capsule is narrower than the stamp's box, which leaves room for the check
        static let stampCapsuleRatio: CGFloat = 10 / 12
        static let symbolPointSize: CGFloat = 96
        static let compactSymbolPointSize: CGFloat = 72
        static let titleSize: CGFloat = 26
        static let compactTitleSize: CGFloat = 22
        static let messageSize: CGFloat = 16
        static let secondarySize: CGFloat = 16
        static let heroToTitle: CGFloat = 22
        static let compactHeroToTitle: CGFloat = 12
        static let titleToMessage: CGFloat = 8
        static let compactTitleToMessage: CGFloat = 6
        /// The message group's side inset inside its column
        static let messageInset: CGFloat = 12
        static let messageMaximumWidth: CGFloat = 420
        /// Under this much room for the message group the hero and its gaps shrink (iPhone SE)
        static let regularMessageMinimumHeight: CGFloat = 280
        static let messageToActions: CGFloat = 16
        static let actionsSpacing: CGFloat = 12
        static let primaryToSlot: CGFloat = 10
        static let primaryFontSize: CGFloat = 16
        static let primaryIconSize: CGFloat = 14
    }

    /// How the board layout is arranged around the iPhone Duo fold.
    private enum Arrangement {
        /// One column: the message group above the actions.
        case single
        /// A vertical fold: the message group before it, the actions after it.
        case sideBySide
        /// A horizontal fold: the message group above it, the actions below it.
        case stacked
    }

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var actionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .medium

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
        return button
    }()

    private lazy var secondaryButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.cornerStyle = .capsule
        config.buttonSize = .medium

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleSecondaryTap), for: .touchUpInside)
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var onAction: (() -> Void)?
    private var onSecondaryAction: (() -> Void)?

    // MARK: Board layout

    /// Holds the board layout; its edges follow the safe area and the tab rail.
    private let boardView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    /// The room the message group is centered in.
    private let messageGuide = UILayoutGuide()

    private let messageStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let stampView: ReviewStampView = {
        let view = ReviewStampView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.capsuleWidth = Layout.stampSize.width * Layout.stampCapsuleRatio
        // The states sit on `.mainBackground`, so in dark mode the check's border is that surface
        view.checkBorderColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .mainBackground : ThemeManager.Colors.statusGreen
        }
        return view
    }()

    private let symbolView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray3
        imageView.isAccessibilityElement = false
        return imageView
    }()

    private let heroTitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: Layout.titleSize, weight: .heavy)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }()

    private let heroMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.messageSize, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        // The last thing to give when a short column runs out of room
        label.setContentCompressionResistancePriority(.defaultHigh - 1, for: .vertical)
        return label
    }()

    private let actionsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Layout.actionsSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let accessoryContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()

    private let primaryRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = Layout.primaryToSlot
        return stack
    }()

    private lazy var primaryButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
        return button
    }()

    /// Holds the place of the global bin button beside the primary button.
    private let trailingSlotView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.isHidden = true
        return view
    }()

    private lazy var quietButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.baseForegroundColor = .label
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(handleSecondaryTap), for: .touchUpInside)
        return button
    }()

    /// Width of the slot beside the primary button (MonthReview's completion puts the global
    /// bin there); nil for none. Read the slot with `trailingSlotFrameInWindow`.
    var trailingSlotWidth: CGFloat? {
        didSet {
            guard trailingSlotWidth != oldValue else { return }
            trailingSlotWidthConstraint?.constant = trailingSlotWidth ?? 0
            trailingSlotView.isHidden = trailingSlotWidth == nil
        }
    }

    /// The slot's frame in window coordinates, laid out first; nil without a slot or a window.
    var trailingSlotFrameInWindow: CGRect? {
        guard hasBuiltBoard, trailingSlotWidth != nil, window != nil, !boardView.isHidden else { return nil }
        layoutIfNeeded()
        let frame = trailingSlotView.convert(trailingSlotView.bounds, to: nil)
        return frame.width > 0 && frame.height > 0 ? frame : nil
    }

    private var hasBuiltBoard = false
    private var hero: Hero = .stamp
    private var isCompactHero = false
    private var primaryTitle: String?
    private var primaryIcon: String?
    private var boardEdges: DuoEdgeConstraints?
    private var arrangement: Arrangement?
    private var arrangementConstraints: [Arrangement: [NSLayoutConstraint]] = [:]
    private var stampWidthConstraint: NSLayoutConstraint?
    private var stampHeightConstraint: NSLayoutConstraint?
    private var trailingSlotWidthConstraint: NSLayoutConstraint?
    /// Distances from this view's leading (side by side) or top (stacked) edge to the fold gap
    private var messageEndAtFoldConstraints: [Arrangement: NSLayoutConstraint] = [:]
    private var actionsStartAtFoldConstraints: [Arrangement: NSLayoutConstraint] = [:]
    /// Fully open at a horizontal fold the two halves read as one screen, so the message group
    /// rests on the fold gap instead of centering in the upper half (which left a wide empty band)
    private var messageRestsOnFoldConstraint: NSLayoutConstraint?
    /// Centers the message group in its room; off while it rests on the fold, or the two pull
    /// the stack taller and spread the title and message apart
    private var messageCenteredConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
        ])
        
        alpha = 0
    }
    
    func configure(
        icon: String? = nil,
        iconColor: UIColor = .systemGray,
        title: String,
        message: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        boardView.isHidden = true
        stackView.isHidden = false
        accessibilityElements = nil
        self.onAction = nil
        self.onSecondaryAction = nil
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let icon = icon {
            iconImageView.image = UIImage(systemName: icon)
            iconImageView.tintColor = iconColor
            stackView.addArrangedSubview(iconImageView)

            NSLayoutConstraint.activate([
                iconImageView.widthAnchor.constraint(equalToConstant: 60),
                iconImageView.heightAnchor.constraint(equalToConstant: 60)
            ])

            stackView.setCustomSpacing(24, after: iconImageView)
        }

        titleLabel.text = title
        stackView.addArrangedSubview(titleLabel)
        stackView.setCustomSpacing(8, after: titleLabel)

        messageLabel.text = message
        stackView.addArrangedSubview(messageLabel)

        if let actionTitle = actionTitle, onAction != nil {
            var config = actionButton.configuration ?? UIButton.Configuration.filled()
            config.title = actionTitle
            actionButton.configuration = config

            self.onAction = onAction

            stackView.setCustomSpacing(24, after: messageLabel)
            stackView.addArrangedSubview(actionButton)
        }

        if let secondaryTitle = secondaryActionTitle, onSecondaryAction != nil {
            var config = secondaryButton.configuration ?? UIButton.Configuration.tinted()
            config.title = secondaryTitle
            secondaryButton.configuration = config

            self.onSecondaryAction = onSecondaryAction

            stackView.setCustomSpacing(12, after: actionButton)
            stackView.addArrangedSubview(secondaryButton)
        }
    }

    // MARK: - Board layout

    /// The board layout: hero, title and message centered above the actions column.
    /// - Parameters:
    ///   - accessory: a view pinned above the buttons, full width (the "Keep going" list, a
    ///     summary card). The view owns its height.
    ///   - actionIcon: an SF Symbol before the primary button's title.
    func configure(
        hero: Hero,
        title: String,
        message: String,
        accessory: UIView? = nil,
        actionTitle: String? = nil,
        actionIcon: String? = nil,
        onAction: (() -> Void)? = nil,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        buildBoardIfNeeded()
        stackView.isHidden = true
        boardView.isHidden = false

        self.hero = hero
        stampView.isHidden = hero != .stamp
        symbolView.isHidden = hero == .stamp
        applyHeroSize()

        heroTitleLabel.text = title
        heroMessageLabel.text = message

        accessoryContainer.subviews.forEach { $0.removeFromSuperview() }
        accessoryContainer.isHidden = accessory == nil
        if let accessory {
            accessory.translatesAutoresizingMaskIntoConstraints = false
            accessoryContainer.addSubview(accessory)
            NSLayoutConstraint.activate([
                accessory.topAnchor.constraint(equalTo: accessoryContainer.topAnchor),
                accessory.leadingAnchor.constraint(equalTo: accessoryContainer.leadingAnchor),
                accessory.trailingAnchor.constraint(equalTo: accessoryContainer.trailingAnchor),
                accessory.bottomAnchor.constraint(equalTo: accessoryContainer.bottomAnchor)
            ])
        }

        let showsPrimary = actionTitle != nil && onAction != nil
        self.onAction = showsPrimary ? onAction : nil
        primaryTitle = showsPrimary ? actionTitle : nil
        primaryIcon = showsPrimary ? actionIcon : nil
        primaryRow.isHidden = !showsPrimary
        applyPrimaryButtonStyle()

        let showsSecondary = secondaryTitle != nil && onSecondary != nil
        onSecondaryAction = showsSecondary ? onSecondary : nil
        quietButton.isHidden = !showsSecondary
        if let secondaryTitle, showsSecondary {
            var config = quietButton.configuration ?? UIButton.Configuration.plain()
            var attributed = AttributedString(secondaryTitle)
            attributed.font = .systemFont(ofSize: Layout.secondarySize, weight: .semibold)
            config.attributedTitle = attributed
            quietButton.configuration = config
        }
        // The secondary is its own 44pt row, so it needs no gap above it
        actionsStack.setCustomSpacing(showsSecondary ? 0 : Layout.actionsSpacing, after: primaryRow)

        accessibilityElements = [heroTitleLabel, heroMessageLabel, accessoryContainer, primaryButton, quietButton]
        setNeedsLayout()
    }

    /// The tab rail's edge in the host's view, on every layout pass
    /// (`DuoLayout.railEdge(tabBarController, in: view)`).
    func update(railEdge: DuoLayout.RailEdge?) {
        boardEdges?.update(railEdge: railEdge)
    }

    private func buildBoardIfNeeded() {
        guard !hasBuiltBoard else { return }
        hasBuiltBoard = true

        addSubview(boardView)
        boardView.addLayoutGuide(messageGuide)
        boardView.addSubview(messageStack)
        boardView.addSubview(actionsStack)

        [stampView, symbolView, heroTitleLabel, heroMessageLabel].forEach { messageStack.addArrangedSubview($0) }
        primaryRow.addArrangedSubview(primaryButton)
        primaryRow.addArrangedSubview(trailingSlotView)
        [accessoryContainer, primaryRow, quietButton].forEach { actionsStack.addArrangedSubview($0) }

        // The bottom row rests on Home's baseline, also on the vertical rail
        let edges = DuoEdgeConstraints(
            item: boardView, in: self,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content,
            standardBottom: GeneralConstants.Spacer.buttonBottom)
        boardEdges = edges

        let stampWidth = stampView.widthAnchor.constraint(equalToConstant: Layout.stampSize.width)
        let stampHeight = stampView.heightAnchor.constraint(equalToConstant: Layout.stampSize.height)
        stampWidthConstraint = stampWidth
        stampHeightConstraint = stampHeight
        let slotWidth = trailingSlotView.widthAnchor.constraint(equalToConstant: trailingSlotWidth ?? 0)
        trailingSlotWidthConstraint = slotWidth

        let centered = messageStack.centerYAnchor.constraint(equalTo: messageGuide.centerYAnchor)
        centered.priority = .defaultHigh
        messageCenteredConstraint = centered
        let widthCap = messageStack.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.messageMaximumWidth)

        NSLayoutConstraint.activate(edges.initialConstraints + [
            boardView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor),

            centered,
            messageStack.centerXAnchor.constraint(equalTo: messageGuide.centerXAnchor),
            messageStack.topAnchor.constraint(greaterThanOrEqualTo: messageGuide.topAnchor),
            messageStack.bottomAnchor.constraint(lessThanOrEqualTo: messageGuide.bottomAnchor),
            messageStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: messageGuide.leadingAnchor, constant: Layout.messageInset),
            messageStack.trailingAnchor.constraint(
                lessThanOrEqualTo: messageGuide.trailingAnchor, constant: -Layout.messageInset),
            widthCap,

            stampWidth,
            stampHeight,
            slotWidth,
            primaryButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            quietButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.medium)
        ])

        // One column: the message group above the actions
        arrangementConstraints[.single] = [
            messageGuide.topAnchor.constraint(equalTo: boardView.topAnchor),
            messageGuide.leadingAnchor.constraint(equalTo: boardView.leadingAnchor),
            messageGuide.trailingAnchor.constraint(equalTo: boardView.trailingAnchor),
            messageGuide.bottomAnchor.constraint(equalTo: actionsStack.topAnchor, constant: -Layout.messageToActions),
            actionsStack.leadingAnchor.constraint(equalTo: boardView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: boardView.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: boardView.bottomAnchor)
        ]

        // A vertical fold: the message group before it, the actions after it
        let messageEndsBeforeFold = messageGuide.trailingAnchor.constraint(equalTo: leadingAnchor)
        let actionsStartAfterFold = actionsStack.leadingAnchor.constraint(equalTo: leadingAnchor)
        messageEndAtFoldConstraints[.sideBySide] = messageEndsBeforeFold
        actionsStartAtFoldConstraints[.sideBySide] = actionsStartAfterFold
        arrangementConstraints[.sideBySide] = [
            messageGuide.topAnchor.constraint(equalTo: boardView.topAnchor),
            messageGuide.bottomAnchor.constraint(equalTo: boardView.bottomAnchor),
            messageGuide.leadingAnchor.constraint(equalTo: boardView.leadingAnchor),
            messageEndsBeforeFold,
            actionsStartAfterFold,
            actionsStack.trailingAnchor.constraint(equalTo: boardView.trailingAnchor),
            // Each half centers its own group, so the two read as one row across the fold
            // (pinned to the baseline, the actions left their half empty above them)
            actionsStack.centerYAnchor.constraint(equalTo: messageGuide.centerYAnchor),
            actionsStack.topAnchor.constraint(greaterThanOrEqualTo: boardView.topAnchor),
            actionsStack.bottomAnchor.constraint(lessThanOrEqualTo: boardView.bottomAnchor)
        ]

        // A horizontal fold: the message group above it, the actions below it
        let messageEndsAboveFold = messageGuide.bottomAnchor.constraint(equalTo: topAnchor)
        let actionsStartBelowFold = actionsStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor)
        messageEndAtFoldConstraints[.stacked] = messageEndsAboveFold
        actionsStartAtFoldConstraints[.stacked] = actionsStartBelowFold
        arrangementConstraints[.stacked] = [
            messageGuide.topAnchor.constraint(equalTo: boardView.topAnchor),
            messageGuide.leadingAnchor.constraint(equalTo: boardView.leadingAnchor),
            messageGuide.trailingAnchor.constraint(equalTo: boardView.trailingAnchor),
            messageEndsAboveFold,
            actionsStartBelowFold,
            actionsStack.leadingAnchor.constraint(equalTo: boardView.leadingAnchor),
            actionsStack.trailingAnchor.constraint(equalTo: boardView.trailingAnchor),
            actionsStack.bottomAnchor.constraint(equalTo: boardView.bottomAnchor)
        ]

        messageRestsOnFoldConstraint = messageStack.bottomAnchor.constraint(equalTo: messageGuide.bottomAnchor)

        applyArrangement(.single)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: EmptyStateView, _: UITraitCollection) in
                self.applyPrimaryButtonStyle()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyPrimaryButtonStyle()
        }
    }

    override func layoutSubviews() {
        if hasBuiltBoard, !boardView.isHidden {
            updateFoldArrangement()
        }
        super.layoutSubviews()
        if hasBuiltBoard, !boardView.isHidden {
            updateHeroSizeForHeight()
        }
    }

    /// Nothing tappable goes on the iPhone Duo fold: where it divides this view, the message
    /// group and the actions take a side each. Read on every layout pass (inactive included, so
    /// folding only moves the gap).
    private func updateFoldArrangement() {
        var fold = FoldRegion.splittingFold(in: self)
        // A horizontal fold only splits the inner display (regular width)
        if let candidate = fold, candidate.width >= candidate.height,
           traitCollection.horizontalSizeClass != .regular {
            fold = nil
        }
        guard let fold else {
            applyArrangement(.single)
            setMessageRestsOnFold(false)
            return
        }
        let isVertical = fold.height > fold.width
        let target: Arrangement = isVertical ? .sideBySide : .stacked
        applyArrangement(target)

        let foldStart = isVertical ? fold.minX : fold.minY
        let foldLength = isVertical ? fold.width : fold.height
        // Fully open the gap is centered on the fold line; folded it clears the whole region
        let isFolded = FoldRegion.activeFold(in: self) != nil
        // Partly folded the raised half is its own screen and the group centers in it
        setMessageRestsOnFold(!isVertical && !isFolded)
        let gap = isFolded ? max(GeneralConstants.Spacer.foldGap, foldLength) : GeneralConstants.Spacer.foldGap
        var gapStart = foldStart + foldLength / 2 - gap / 2
        // The fold is in physical coordinates; the side-by-side constraints measure from leading
        if isVertical, effectiveUserInterfaceLayoutDirection == .rightToLeft {
            gapStart = bounds.width - gapStart - gap
        }
        if let messageEnd = messageEndAtFoldConstraints[target], messageEnd.constant != gapStart {
            messageEnd.constant = gapStart
        }
        if let actionsStart = actionsStartAtFoldConstraints[target], actionsStart.constant != gapStart + gap {
            actionsStart.constant = gapStart + gap
        }
    }

    private func setMessageRestsOnFold(_ rests: Bool) {
        guard let constraint = messageRestsOnFoldConstraint, constraint.isActive != rests else { return }
        // Deactivate before activating, so the two never hold at once
        if rests {
            messageCenteredConstraint?.isActive = false
            constraint.isActive = true
        } else {
            constraint.isActive = false
            messageCenteredConstraint?.isActive = true
        }
    }

    private func applyArrangement(_ target: Arrangement) {
        guard target != arrangement else { return }
        if let arrangement {
            NSLayoutConstraint.deactivate(arrangementConstraints[arrangement] ?? [])
        }
        arrangement = target
        NSLayoutConstraint.activate(arrangementConstraints[target] ?? [])
    }

    /// A short column (iPhone SE) keeps the order and scrolls nothing: the hero and its gaps
    /// shrink. Decided after layout from the room the message group has, which doesn't depend
    /// on the hero's own size.
    private func updateHeroSizeForHeight() {
        let available = messageGuide.layoutFrame.height
        guard available > 0 else { return }
        let isCompact = available < Layout.regularMessageMinimumHeight
        guard isCompact != isCompactHero else { return }
        isCompactHero = isCompact
        applyHeroSize()
        setNeedsLayout()
    }

    private func applyHeroSize() {
        let stampSize = isCompactHero ? Layout.compactStampSize : Layout.stampSize
        stampWidthConstraint?.constant = stampSize.width
        stampHeightConstraint?.constant = stampSize.height
        stampView.capsuleWidth = stampSize.width * Layout.stampCapsuleRatio
        if case .symbol(let name) = hero {
            let config = UIImage.SymbolConfiguration(
                pointSize: isCompactHero ? Layout.compactSymbolPointSize : Layout.symbolPointSize, weight: .thin)
            symbolView.image = UIImage(systemName: name, withConfiguration: config)
        }
        heroTitleLabel.font = ThemeManager.Fonts.titleFont(
            size: isCompactHero ? Layout.compactTitleSize : Layout.titleSize, weight: .heavy)
        let heroView: UIView = hero == .stamp ? stampView : symbolView
        messageStack.setCustomSpacing(isCompactHero ? Layout.compactHeroToTitle : Layout.heroToTitle, after: heroView)
        messageStack.setCustomSpacing(
            isCompactHero ? Layout.compactTitleToMessage : Layout.titleToMessage, after: heroTitleLabel)
    }

    /// An ink pill, as the month hub's Continue: the colors are resolved for the current
    /// appearance, because the glass doesn't keep a dynamic title color legible.
    private func applyPrimaryButtonStyle() {
        guard hasBuiltBoard, let primaryTitle else { return }
        primaryButton.configure(
            title: primaryTitle,
            systemImage: primaryIcon,
            style: .prominent,
            backgroundColor: UIColor.label.resolvedColor(with: traitCollection),
            foregroundColor: UIColor.systemBackground.resolvedColor(with: traitCollection),
            fontSize: Layout.primaryFontSize,
            fontWeight: .bold,
            iconSize: Layout.primaryIconSize,
            iconWeight: .bold)
    }
    
    @objc private func handleActionTap() {
        onAction?()
    }

    @objc private func handleSecondaryTap() {
        onSecondaryAction?()
    }
    
    func show(animated: Bool = true) {
        guard animated else {
            alpha = 1
            return
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }
    }
    
    func hide(animated: Bool = true) {
        guard animated else {
            alpha = 0
            return
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

// MARK: - Previews

#if DEBUG

@available(iOS 17.0, *)
#Preview("Icon + Title + Message") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        icon: "photo.on.rectangle.angled",
        title: NSLocalizedString("monthHelpers.noResultsTitle", comment: ""),
        message: NSLocalizedString("monthHelpers.noResultsMessage", comment: "")
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Icon + Title + Message + Action") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        icon: "trash.slash",
        title: NSLocalizedString("deleteBin.emptyMessage", comment: ""),
        message: NSLocalizedString("deleteBin.yourDeleteBin", comment: ""),
        actionTitle: NSLocalizedString("dashboard.getStarted", comment: ""),
        onAction: {}
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Icon + Title + Message + Both Buttons") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        icon: "exclamationmark.triangle",
        title: "Access Denied",
        message: "Please grant photo library access to use this feature.",
        actionTitle: "Open Settings",
        onAction: {},
        secondaryActionTitle: "Learn More",
        onSecondaryAction: {}
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Title + Message Only") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        title: NSLocalizedString("similarPhotos.noneTitle", comment: ""),
        message: NSLocalizedString("similarPhotos.noneMessageLibraryUncounted", comment: "")
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Board: stamp + buttons") {
    let vc = UIViewController()
    vc.view.backgroundColor = .mainBackground
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        hero: .stamp,
        title: NSLocalizedString("deleteBin.allCleanedTitle", comment: ""),
        message: NSLocalizedString("deleteBin.emptyHint", comment: ""),
        actionTitle: NSLocalizedString("deleteBin.reviewAnother", comment: ""),
        actionIcon: "play.fill",
        onAction: {},
        secondaryTitle: NSLocalizedString("deleteBin.done", comment: ""),
        onSecondary: {}
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Board: symbol") {
    let vc = UIViewController()
    vc.view.backgroundColor = .mainBackground
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        hero: .symbol("trash"),
        title: NSLocalizedString("deleteBin.yourDeleteBin", comment: ""),
        message: NSLocalizedString("deleteBin.emptyHint", comment: ""),
        actionTitle: NSLocalizedString("deleteBin.reviewPhotos", comment: ""),
        actionIcon: "play.fill",
        onAction: {}
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

#endif

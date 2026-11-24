//
//  FilterCard.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.02.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let allCaughtUp = NSLocalizedString("filterCards.allCaughtUp", comment: "Status of a fully reviewed filter")
    static let notStarted = NSLocalizedString("filterCards.notStarted", comment: "Status of a filter nobody has reviewed yet")
    static func percentReviewed(_ percent: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("filterCards.percentReviewed", comment: "Status of a filter in progress: 42% reviewed"),
            percent)
    }
}

/// A tappable card with an icon and a title, in one of three styles the screen picks:
/// - `.link`: icon, title and chevron (Home's Photos / Videos tiles), tall once there's room.
/// - `.tile`: the month hub's filter tile, with a review capsule and a status on the bottom edge.
/// - `.row`: the same content on one line, with the status and the capsule before the chevron.
final class FilterCard: UIControl {
    private enum Layout {
        /// From this height (with `allowsTallVariant`) a `.link` card uses its tall layout
        static let tallMinimumHeight: CGFloat = 110
        static let compactIconSize: CGFloat = 28
        static let compactIconPointSize: CGFloat = 18
        static let compactTitleSize: CGFloat = 15
        static let compactInset: CGFloat = 12
        static let tallIconSize: CGFloat = 30
        static let tallIconPointSize: CGFloat = 30
        static let tallTitleSize: CGFloat = 20
        static let tallInset: CGFloat = 16
        static let linkIconToText: CGFloat = 10
        static let linkTextToChevron: CGFloat = 8

        /// Tiles and rows
        static let progressInset: CGFloat = 16
        static let progressIconSize: CGFloat = 28
        static let progressIconPointSize: CGFloat = 22
        static let progressTitleSize: CGFloat = 17
        static let statusSize: CGFloat = 12
        /// The least room between a tile's top row and its title; the free height goes here
        static let topRowToTitle: CGFloat = 6
        /// The finished capsule's stamp is wider than the capsule; this keeps it off the edge
        /// and off its neighbors
        static let capsuleStampRoom: CGFloat = 6
        /// A tile's title rests right above its status
        static let titleToStatus: CGFloat = 4
        /// A tile too short for the top row over a two-line title packs tighter: smaller insets,
        /// and the title right under the icon, beside the capsule
        static let progressTitleMinimumScale: CGFloat = 0.85
        static let tightInset: CGFloat = 12
        static let tightIconToTitle: CGFloat = 6
        static let tightTextToCapsule: CGFloat = 8
        static let rowIconToText: CGFloat = 12
        static let rowTextToStatus: CGFloat = 8
        static let rowStatusToCapsule: CGFloat = 8
        static let rowCapsuleToChevron: CGFloat = 8
        static let rowMinimumVerticalInset: CGFloat = 10
        static let chevronSize = CGSize(width: 10, height: 14)
    }

    enum Style {
        case link
        case tile
        case row
    }

    enum CardColor {
        static let similar: UIColor = .photo100
        static let largestPhoto: UIColor = .photo100
        static let screenshots: UIColor = .photo100
        static let eyesClosed: UIColor = .photo100
        static let allPhotos: UIColor = .photo100
        static let screenRecordings: UIColor = .video100
        static let slowMotion: UIColor = .video100
        static let largestVideo: UIColor = .video100
        static let timeLapse: UIColor = .video100
        static let allVideos: UIColor = .video100
    }

    /// The constraint set in use: a `.link` card has two, by its height
    private enum Variant {
        case linkCompact
        case linkTall
        case tile
        /// A tile too short for the title under the whole top row
        case tileTight
        case row
    }

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: Layout.compactTitleSize, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        return label
    }()

    private let chevronIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private let capsuleView: ReviewCapsuleView = {
        let view = ReviewCapsuleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        // Progress only: the overview card carries the delete / keep / store split
        view.usesSingleProgressColor = true
        return view
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.statusSize, weight: .semibold)
        label.textColor = .textSecondary
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        label.isHidden = true
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    /// Lets a `.link` card switch to its tall layout (icon and chevron at the top, a larger title
    /// at the bottom) once it's at least 110pt tall. Off by default.
    var allowsTallVariant = false {
        didSet { setNeedsLayout() }
    }

    private var style: Style = .link
    private var iconName: String?
    private var appliedVariant: Variant?
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var variantConstraints: [Variant: [NSLayoutConstraint]] = [:]

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                self.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let variant = currentVariant
        if appliedVariant != variant {
            applyVariant(variant)
            // The new constraints place the text before its lines are fitted below
            super.layoutSubviews()
        }
        fitText(for: variant)
    }

    private var currentVariant: Variant {
        switch style {
        case .tile: return bounds.height > 0 && bounds.height < tileMinimumHeight ? .tileTight : .tile
        case .row: return .row
        case .link:
            return allowsTallVariant && bounds.height >= Layout.tallMinimumHeight ? .linkTall : .linkCompact
        }
    }

    /// The shortest tile that holds the top row, a two-line title and the status. It doesn't
    /// depend on the tile's own title, so tiles of one height always share an arrangement.
    private var tileMinimumHeight: CGFloat {
        let titleFont = ThemeManager.Fonts.titleFont(size: Layout.progressTitleSize, weight: .semibold)
        return Layout.progressInset + capsuleView.intrinsicContentSize.height + Layout.topRowToTitle
            + 2 * titleFont.lineHeight + Layout.titleToStatus + statusLabel.font.lineHeight
            + Layout.progressInset
    }

    private func applyVariant(_ variant: Variant) {
        if let applied = appliedVariant {
            NSLayoutConstraint.deactivate(variantConstraints[applied] ?? [])
        }
        appliedVariant = variant
        NSLayoutConstraint.activate(variantConstraints[variant] ?? [])

        let iconSize: CGFloat
        switch variant {
        case .linkCompact:
            iconSize = Layout.compactIconSize
            titleLabel.font = ThemeManager.Fonts.titleFont(size: Layout.compactTitleSize, weight: .semibold)
        case .linkTall:
            iconSize = Layout.tallIconSize
            titleLabel.font = ThemeManager.Fonts.titleFont(size: Layout.tallTitleSize, weight: .bold)
        case .tile, .tileTight, .row:
            iconSize = Layout.progressIconSize
            titleLabel.font = ThemeManager.Fonts.titleFont(size: Layout.progressTitleSize, weight: .semibold)
        }
        iconWidthConstraint?.constant = iconSize
        iconHeightConstraint?.constant = iconSize
        updateIconImage()

        let isTile = variant == .tile || variant == .tileTight
        let showsProgress = isTile || variant == .row
        // Tiles and rows sit side by side, so their titles keep one size: they wrap instead of
        // shrinking, except a little for a word wider than the card.
        titleLabel.minimumScaleFactor = showsProgress ? Layout.progressTitleMinimumScale : 0.7
        capsuleView.isHidden = !showsProgress
        statusLabel.isHidden = !showsProgress
        chevronIcon.isHidden = isTile
    }

    /// Gives the title the lines it needs (two at most) when the card's own height holds them,
    /// else one.
    private func fitText(for variant: Variant) {
        let available: CGFloat
        switch variant {
        case .linkCompact, .linkTall:
            setTitleLines(2)
            return
        case .tile:
            let topRow = Layout.progressInset + capsuleView.intrinsicContentSize.height + Layout.topRowToTitle
            let bottom = Layout.titleToStatus + statusLabel.font.lineHeight + Layout.progressInset
            available = bounds.height - topRow - bottom
        case .tileTight:
            let top = Layout.tightInset + Layout.progressIconSize + Layout.tightIconToTitle
            let bottom = Layout.titleToStatus + statusLabel.font.lineHeight + Layout.tightInset
            available = bounds.height - top - bottom
        case .row:
            available = bounds.height - 2 * Layout.rowMinimumVerticalInset
        }

        let width = textStack.bounds.width
        guard width > 0, bounds.height > 0 else { return }

        var titleLines = lineCount(of: titleLabel, width: width, limit: 2)
        // A row's title that nearly fits one line stays on it, a little smaller, rather than
        // wrapping beside a long status
        if variant == .row, titleLines > 1,
           singleLineWidth(of: titleLabel) * Layout.progressTitleMinimumScale <= width {
            titleLines = 1
        }
        let fits = CGFloat(titleLines) * titleLabel.font.lineHeight <= available + 0.5
        setTitleLines(fits ? titleLines : 1)
    }

    private func setTitleLines(_ lines: Int) {
        if titleLabel.numberOfLines != lines { titleLabel.numberOfLines = lines }
    }

    private func lineCount(of label: UILabel, width: CGFloat, limit: Int) -> Int {
        guard let text = label.text, !text.isEmpty, let font = label.font else { return 1 }
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font], context: nil)
        return min(limit, max(1, Int((rect.height / font.lineHeight).rounded())))
    }

    private func singleLineWidth(of label: UILabel) -> CGFloat {
        guard let text = label.text, let font = label.font else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private func updateIconImage() {
        guard let iconName else { return }
        let pointSize: CGFloat
        switch appliedVariant {
        case .linkTall: pointSize = Layout.tallIconPointSize
        case .tile, .tileTight, .row: pointSize = Layout.progressIconPointSize
        case .linkCompact, nil: pointSize = Layout.compactIconPointSize
        }
        let iconConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: iconConfig)
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        textStack.addArrangedSubview(titleLabel)
        // The card's height comes from outside; the title's lines are fitted in layoutSubviews
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        [iconView, textStack, chevronIcon, capsuleView, statusLabel].forEach { addSubview($0) }

        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    private func setupConstraint() {
        let iconWidth = iconView.widthAnchor.constraint(equalToConstant: Layout.compactIconSize)
        let iconHeight = iconView.heightAnchor.constraint(equalToConstant: Layout.compactIconSize)
        iconWidthConstraint = iconWidth
        iconHeightConstraint = iconHeight

        variantConstraints[.linkCompact] = [
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.compactInset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Layout.linkIconToText),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: chevronIcon.leadingAnchor, constant: -Layout.linkTextToChevron),
            chevronIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.compactInset),
            chevronIcon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]
        // Icon at the top-leading corner, title at the bottom-leading one, chevron top-trailing
        variantConstraints[.linkTall] = [
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.tallInset),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.tallInset),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.tallInset),
            textStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.tallInset),
            textStack.trailingAnchor.constraint(equalTo: chevronIcon.leadingAnchor, constant: -Layout.linkTextToChevron),
            chevronIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.tallInset),
            chevronIcon.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ]

        let inset = Layout.progressInset
        // The title rests right above the status on the bottom edge, level with the neighboring
        // tile's; the free height sits between the top row and the title
        let tileTitleBelowTopRow = textStack.topAnchor.constraint(
            greaterThanOrEqualTo: capsuleView.bottomAnchor, constant: Layout.topRowToTitle)
        tileTitleBelowTopRow.priority = .defaultHigh
        variantConstraints[.tile] = [
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            capsuleView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            capsuleView.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -(inset + Layout.capsuleStampRoom)),
            tileTitleBelowTopRow,
            textStack.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -Layout.titleToStatus),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -inset),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset)
        ]

        let tight = Layout.tightInset
        let tightTitleBelowIcon = textStack.topAnchor.constraint(
            greaterThanOrEqualTo: iconView.bottomAnchor, constant: Layout.tightIconToTitle)
        tightTitleBelowIcon.priority = .defaultHigh
        variantConstraints[.tileTight] = [
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: tight),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: tight),
            capsuleView.topAnchor.constraint(equalTo: topAnchor, constant: tight),
            capsuleView.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -(tight + Layout.capsuleStampRoom)),
            tightTitleBelowIcon,
            textStack.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -Layout.titleToStatus),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: tight),
            textStack.trailingAnchor.constraint(
                equalTo: capsuleView.leadingAnchor, constant: -(Layout.tightTextToCapsule + Layout.capsuleStampRoom)),
            statusLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: tight),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -tight),
            statusLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -tight)
        ]

        let rowTextTop = textStack.topAnchor.constraint(
            greaterThanOrEqualTo: topAnchor, constant: Layout.rowMinimumVerticalInset)
        rowTextTop.priority = .defaultHigh
        variantConstraints[.row] = [
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Layout.rowIconToText),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            rowTextTop,
            textStack.trailingAnchor.constraint(
                equalTo: statusLabel.leadingAnchor, constant: -Layout.rowTextToStatus),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusLabel.trailingAnchor.constraint(
                equalTo: capsuleView.leadingAnchor, constant: -(Layout.rowStatusToCapsule + Layout.capsuleStampRoom)),
            capsuleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            capsuleView.trailingAnchor.constraint(
                equalTo: chevronIcon.leadingAnchor, constant: -(Layout.rowCapsuleToChevron + Layout.capsuleStampRoom)),
            chevronIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            chevronIcon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]

        NSLayoutConstraint.activate([
            iconWidth,
            iconHeight,
            chevronIcon.widthAnchor.constraint(equalToConstant: Layout.chevronSize.width),
            chevronIcon.heightAnchor.constraint(equalToConstant: Layout.chevronSize.height),
            capsuleView.widthAnchor.constraint(equalToConstant: capsuleView.intrinsicContentSize.width),
            capsuleView.heightAnchor.constraint(equalToConstant: capsuleView.intrinsicContentSize.height)
        ])
        applyVariant(.linkCompact)
    }

    // MARK: - Configure

    /// The screen picks the style; a card never changes it by its own size.
    func configure(icon: String, title: String, tintColor: UIColor, style: Style = .link) {
        iconName = icon
        updateIconImage()
        iconView.tintColor = tintColor
        titleLabel.text = title

        layer.borderWidth = 0
        layer.borderColor = tintColor.withAlphaComponent(0.3).cgColor

        setStyle(style)
        updateAccessibilityLabel()
    }

    func setStyle(_ style: Style) {
        guard style != self.style else { return }
        self.style = style
        updateAccessibilityLabel()
        setNeedsLayout()
    }

    /// The review state of a `.tile` or `.row` card, from its own progress record. The card is
    /// complete when `isFinished` (the finished flag wins over the counts) or when
    /// `total > 0 && reviewed >= total`, and not started while nothing is reviewed.
    func setProgress(deleted: Int, kept: Int, stored: Int, total: Int, reviewed: Int, isFinished: Bool) {
        if isFinished || (total > 0 && reviewed >= total) {
            // A finished flag can come with no counts at all: the stamp either way
            capsuleView.configure(deleted: 0, kept: 0, stored: 0, total: 1, reviewed: 1)
            statusLabel.text = Strings.allCaughtUp
            statusLabel.textColor = .systemGreen
        } else if total <= 0 || reviewed <= 0 {
            capsuleView.configure(deleted: 0, kept: 0, stored: 0, total: max(0, total), reviewed: 0)
            statusLabel.text = Strings.notStarted
            statusLabel.textColor = .textSecondary
        } else {
            let percent = reviewed.roundedPercent(of: total)
            capsuleView.configure(deleted: deleted, kept: kept, stored: stored, total: total, reviewed: reviewed)
            statusLabel.text = Strings.percentReviewed(percent)
            statusLabel.textColor = .textSecondary
        }
        updateAccessibilityLabel()
        setNeedsLayout()
    }

    /// One VoiceOver element: "title, status".
    private func updateAccessibilityLabel() {
        let showsStatus = style != .link
        accessibilityLabel = [titleLabel.text, showsStatus ? statusLabel.text : nil]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview {
    let tile = FilterCard()
    tile.configure(
        icon: "photo.on.rectangle.angled",
        title: NSLocalizedString("filterCards.similarTitle", comment: ""),
        tintColor: FilterCard.CardColor.similar,
        style: .tile
    )
    tile.setProgress(deleted: 8, kept: 10, stored: 3, total: 50, reviewed: 21, isFinished: false)

    let done = FilterCard()
    done.configure(
        icon: "camera.viewfinder",
        title: NSLocalizedString("filterCards.screenshotsTitle", comment: ""),
        tintColor: FilterCard.CardColor.screenshots,
        style: .tile
    )
    done.setProgress(deleted: 0, kept: 0, stored: 0, total: 0, reviewed: 0, isFinished: true)

    let row = FilterCard()
    row.configure(
        icon: "photo.on.rectangle",
        title: NSLocalizedString("filterCards.allPhotosTitle", comment: ""),
        tintColor: FilterCard.CardColor.allPhotos,
        style: .row
    )
    row.setProgress(deleted: 0, kept: 0, stored: 0, total: 92, reviewed: 0, isFinished: false)

    let tiles = UIStackView(arrangedSubviews: [tile, done])
    tiles.spacing = 10
    tiles.distribution = .fillEqually
    let stack = UIStackView(arrangedSubviews: [tiles, row])
    stack.axis = .vertical
    stack.spacing = 10
    stack.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        tiles.heightAnchor.constraint(equalToConstant: 170),
        row.heightAnchor.constraint(equalToConstant: 100)
    ])
    return container
}
#endif

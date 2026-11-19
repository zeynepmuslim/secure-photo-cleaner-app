//
//  FilterCard.swift
//  Purgio
//
//  Created by ZeynepMüslim on 24.02.2026.
//

import UIKit

final class FilterCard: UIControl {
    private enum Layout {
        /// From this height (with `allowsTallVariant`) the card uses its tall layout
        static let tallMinimumHeight: CGFloat = 110
        static let compactIconSize: CGFloat = 28
        static let compactIconPointSize: CGFloat = 18
        static let compactTitleSize: CGFloat = 15
        static let compactInset: CGFloat = 12
        static let tallIconSize: CGFloat = 30
        static let tallIconPointSize: CGFloat = 30
        static let tallTitleSize: CGFloat = 20
        static let tallInset: CGFloat = 16
    }

    enum Status {
        case notStarted
        case inProgress(percent: Int)
        case complete
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
        label.font = ThemeManager.Fonts.titleFont(size: 15, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
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
        stack.spacing = 2
        stack.alignment = .leading
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.isUserInteractionEnabled = false
        return stack
    }()

    private let statusBadge: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 10
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private let statusIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = false
        return imageView
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isUserInteractionEnabled = false
        return label
    }()

    private let miniProgressRing: MiniProgressRing = {
        let ring = MiniProgressRing()
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.isHidden = true
        ring.isUserInteractionEnabled = false
        return ring
    }()

    /// Lets the card switch to its tall layout (icon and chevron at the top, a larger title at the
    /// bottom) once it's at least 110pt tall. Off by default, so grids of filter cards keep their look.
    var allowsTallVariant = false {
        didSet { setNeedsLayout() }
    }

    private var iconName: String?
    private var appliedTallVariant: Bool?
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var compactConstraints: [NSLayoutConstraint] = []
    private var tallConstraints: [NSLayoutConstraint] = []

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
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let isTall = allowsTallVariant && bounds.height >= Layout.tallMinimumHeight
        if appliedTallVariant != isTall {
            applyVariant(isTall: isTall)
        }
        // An empty subtitle (Home's tiles) takes no room, so the title centers on the icon
        subtitleLabel.isHidden = isTall || (subtitleLabel.text ?? "").isEmpty
            || bounds.width < GeneralConstants.CompactContentWidth.halfWidthCard
    }

    private func applyVariant(isTall: Bool) {
        appliedTallVariant = isTall
        NSLayoutConstraint.deactivate(isTall ? compactConstraints : tallConstraints)
        NSLayoutConstraint.activate(isTall ? tallConstraints : compactConstraints)

        contentStack.axis = isTall ? .vertical : .horizontal
        contentStack.alignment = isTall ? .leading : .center
        contentStack.distribution = isTall ? .equalSpacing : .fill

        let iconSize = isTall ? Layout.tallIconSize : Layout.compactIconSize
        iconWidthConstraint?.constant = iconSize
        iconHeightConstraint?.constant = iconSize
        updateIconImage()

        titleLabel.font = isTall
            ? ThemeManager.Fonts.titleFont(size: Layout.tallTitleSize, weight: .bold)
            : ThemeManager.Fonts.titleFont(size: Layout.compactTitleSize, weight: .semibold)
    }

    private func updateIconImage() {
        guard let iconName else { return }
        let pointSize = appliedTallVariant == true ? Layout.tallIconPointSize : Layout.compactIconPointSize
        let iconConfig = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: iconConfig)
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)

        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(textStack)

        addSubview(contentStack)
        addSubview(chevronIcon)

        statusBadge.addSubview(statusIcon)
        statusBadge.addSubview(miniProgressRing)
        statusBadge.addSubview(statusLabel)
        addSubview(statusBadge)

        let iconWidth = iconView.widthAnchor.constraint(equalToConstant: Layout.compactIconSize)
        let iconHeight = iconView.heightAnchor.constraint(equalToConstant: Layout.compactIconSize)
        iconWidthConstraint = iconWidth
        iconHeightConstraint = iconHeight

        compactConstraints = [
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.compactInset),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.compactInset),
            chevronIcon.centerYAnchor.constraint(equalTo: centerYAnchor)
        ]
        // Icon at the top-leading corner, title at the bottom-leading one, chevron top-trailing
        tallConstraints = [
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.tallInset),
            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: Layout.tallInset),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.tallInset),
            chevronIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.tallInset),
            chevronIcon.centerYAnchor.constraint(equalTo: iconView.centerYAnchor)
        ]
        appliedTallVariant = false

        NSLayoutConstraint.activate(compactConstraints + [
            iconWidth,
            iconHeight,

            contentStack.trailingAnchor.constraint(equalTo: chevronIcon.leadingAnchor, constant: -8),

            chevronIcon.widthAnchor.constraint(equalToConstant: 10),
            chevronIcon.heightAnchor.constraint(equalToConstant: 14),

            statusBadge.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            statusBadge.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),

            statusIcon.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 6),
            statusIcon.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 10),
            statusIcon.heightAnchor.constraint(equalToConstant: 10),

            miniProgressRing.leadingAnchor.constraint(equalTo: statusBadge.leadingAnchor, constant: 6),
            miniProgressRing.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor),
            miniProgressRing.widthAnchor.constraint(equalToConstant: 10),
            miniProgressRing.heightAnchor.constraint(equalToConstant: 10),

            statusLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 4),
            statusLabel.trailingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: -6),
            statusLabel.centerYAnchor.constraint(equalTo: statusBadge.centerYAnchor)
        ])
    }

    func configure(icon: String, title: String, subtitle: String, tintColor: UIColor) {
        iconName = icon
        updateIconImage()
        iconView.tintColor = tintColor
        titleLabel.text = title
        subtitleLabel.text = subtitle

        layer.borderWidth = 0
        layer.borderColor = tintColor.withAlphaComponent(0.3).cgColor

        statusBadge.isHidden = true
    }

    func setStatus(_ status: Status) {
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)

        switch status {
        case .notStarted:
            statusBadge.isHidden = true
            statusIcon.isHidden = false
            miniProgressRing.isHidden = true

        case .inProgress(let percent):
            statusBadge.isHidden = false
            statusBadge.backgroundColor = UIColor.systemGray.withAlphaComponent(0.25)
            statusLabel.textColor = .label
            statusLabel.text = "\(percent)%"
            statusIcon.isHidden = true
            miniProgressRing.isHidden = false
            miniProgressRing.setProgress(CGFloat(percent) / 100.0)

        case .complete:
            statusBadge.isHidden = false
            statusBadge.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.15)
            statusLabel.textColor = .systemGreen
            statusLabel.text = "Finished"
            statusIcon.isHidden = false
            statusIcon.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: iconConfig)
            statusIcon.tintColor = .systemGreen
            miniProgressRing.isHidden = true
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    let card = FilterCard()
    card.configure(
        icon: "photo.on.rectangle.angled",
        title: NSLocalizedString("filterCards.similarTitle", comment: ""),
        subtitle: NSLocalizedString("filterCards.similarSubtitle", comment: ""),
        tintColor: FilterCard.CardColor.similar
    )
    card.setStatus(.inProgress(percent: 42))
    card.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(card)
    NSLayoutConstraint.activate([
        card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        card.heightAnchor.constraint(equalToConstant: 80)
    ])
    return container
}

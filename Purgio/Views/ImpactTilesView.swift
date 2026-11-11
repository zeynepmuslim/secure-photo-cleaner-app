//
//  ImpactTilesView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// Settings' impact numbers as three equal tiles in a row (space saved, stored items,
/// reviewed), used by every Settings layout. Same numbers as `ImpactStatsView`.
final class ImpactTilesView: UIView {

    // MARK: - Strings
    private enum Strings {
        static let spaceSaved = NSLocalizedString("impactStats.spaceSaved", comment: "Space saved stat label")
        static let itemsStored = NSLocalizedString("impactStats.itemsStored", comment: "Items stored stat label")
        static let totalReviewed = NSLocalizedString("impactStats.totalReviewed", comment: "Total reviewed stat label")
    }

    private let tilesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = GeneralConstants.EdgePadding.small
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let spaceSavedTile = ImpactTile(
        iconName: "sparkles", tintColor: .systemGreen, title: Strings.spaceSaved)
    private let storedTile = ImpactTile(
        iconName: "archivebox.fill", tintColor: ThemeManager.Colors.statusYellow, title: Strings.itemsStored)
    private let reviewedTile = ImpactTile(
        iconName: "eye", tintColor: .label, title: Strings.totalReviewed)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(spaceSaved: String, storedCount: Int, reviewedCount: Int) {
        spaceSavedTile.setValue(spaceSaved)
        storedTile.setValue("\(storedCount)")
        reviewedTile.setValue("\(reviewedCount)")
    }

    /// The single column keeps titles readable on 375pt phones: a title shrinks only a little
    /// on one line, and wraps to a second line when that isn't enough. The split layouts keep
    /// one shrink-to-fit line, which the fold needs. The tiles stay equal in height and keep
    /// the same bottom padding either way.
    func setTitlesWrap(_ wraps: Bool) {
        [spaceSavedTile, storedTile, reviewedTile].forEach { $0.setTitleWraps(wraps) }
    }

    // MARK: - Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        [spaceSavedTile, storedTile, reviewedTile].forEach { tilesStack.addArrangedSubview($0) }
        addSubview(tilesStack)

        NSLayoutConstraint.activate([
            tilesStack.topAnchor.constraint(equalTo: topAnchor),
            tilesStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            tilesStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            tilesStack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

// MARK: - ImpactTile

/// One tile: the icon at the top, then the number, then the title.
private final class ImpactTile: UIView {

    private enum Layout {
        static let padding: CGFloat = 16
        /// Top and bottom; tighter than the sides so the Settings column fits without scrolling
        static let verticalPadding: CGFloat = 14
        static let iconToValue: CGFloat = 6
        static let iconSize: CGFloat = 24
        static let minimumHeight: CGFloat = 100
        static let valueToTitle: CGFloat = 4
        static let wrappedTitleLines = 2
        /// Split layouts: one line, shrinking as far as it takes
        static let shrinkScale: CGFloat = 0.7
        /// Single column: one line only while it stays this readable, else two lines
        static let readableScale: CGFloat = 0.85
    }

    /// Whether the title may wrap (single column), decided against the tile's width on
    /// every layout pass
    private var titleMayWrap = false

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 28, weight: .bold)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .secondaryLabel
        // One line, shrinking to fit, by default: split at the fold a second line would make the
        // tiles taller and push the cards under them off the fold and the baseline
        // (setTitleWraps lets the single column wrap)
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = Layout.shrinkScale
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    init(iconName: String, tintColor: UIColor, title: String) {
        super.init(frame: .zero)
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconView.tintColor = tintColor
        valueLabel.textColor = tintColor
        titleLabel.text = title
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTitleWraps(_ wraps: Bool) {
        titleMayWrap = wraps
        updateTitleLines()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateTitleLines()
    }

    /// One shrink-to-fit line unless the title may wrap and wouldn't stay readable on one
    private func updateTitleLines() {
        let available = bounds.width - 2 * Layout.padding
        var wraps = false
        if titleMayWrap, available > 0, let title = titleLabel.text, let font = titleLabel.font {
            let fullWidth = (title as NSString).size(withAttributes: [.font: font]).width
            wraps = fullWidth * Layout.readableScale > available
        }
        let lines = wraps ? Layout.wrappedTitleLines : 1
        let scale = titleMayWrap ? Layout.readableScale : Layout.shrinkScale
        guard titleLabel.numberOfLines != lines || titleLabel.minimumScaleFactor != scale else { return }
        titleLabel.numberOfLines = lines
        titleLabel.adjustsFontSizeToFitWidth = !wraps
        titleLabel.minimumScaleFactor = scale
        titleLabel.invalidateIntrinsicContentSize()
    }

    func setValue(_ value: String) {
        valueLabel.text = value
        accessibilityLabel = "\(titleLabel.text ?? ""), \(value)"
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true

        addSubview(iconView)
        addSubview(valueLabel)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumHeight),

            iconView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            iconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),

            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: Layout.valueToTitle),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.padding),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.padding),

            // The number and title sit at the bottom, the same padding in every tile; the gap
            // under the icon grows
            valueLabel.topAnchor.constraint(
                greaterThanOrEqualTo: iconView.bottomAnchor, constant: Layout.iconToValue),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding)
        ])
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let tiles = ImpactTilesView()
    tiles.configure(spaceSaved: "6.6 MB", storedCount: 8, reviewedCount: 41)

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(tiles)
    NSLayoutConstraint.activate([
        tiles.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
        tiles.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        tiles.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
    ])
    return container
}
#endif

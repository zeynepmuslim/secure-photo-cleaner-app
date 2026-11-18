//
//  MonthListCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static func photosToReview(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("monthCell.photosToReview", comment: "Photos to review count"), count)
    }

    static func videosToReview(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("monthCell.videosToReview", comment: "Videos to review count"), count)
    }
}

final class MonthListCell: UITableViewCell {

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let rowView: MonthProgressRowView = {
        let view = MonthProgressRowView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let chevronImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // The card draws the row and its corners: no inset-grouped section background
        // (rounded around the whole year) behind it
        backgroundConfiguration = .clear()
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(rowView)
        containerView.addSubview(chevronImageView)

        // The whole row is one VoiceOver element
        isAccessibilityElement = true
        accessibilityTraits = .button

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: MonthListCell, _: UITraitCollection) in
                self.updateSelectionBorderColor()
            }
        }
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            rowView.topAnchor.constraint(equalTo: containerView.topAnchor),
            rowView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            rowView.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor),
            rowView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    // MARK: - Layout

    /// The inset-grouped table rounds each year's section by masking its first and last
    /// cells, which cut the card's own corners (and its selection outline). Each card rounds
    /// itself, so the cell keeps no mask.
    override func layoutSubviews() {
        super.layoutSubviews()
        if layer.cornerRadius != 0 { layer.cornerRadius = 0 }
        if layer.masksToBounds { layer.masksToBounds = false }
    }

    // MARK: - Selection

    /// Only the iPhone Duo's list | detail split keeps a row selected: the row showing in the
    /// detail. Elsewhere rows deselect on tap, so the look never changes there.
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // An outline, not a fill: a gray fill would hide the capsule's gray "left" segment
        // On screen the outline fades between rows as the selection moves
        containerView.layer.setBorderWidth(selected ? 2 : 0, animated: window != nil)
        updateSelectionBorderColor()
        accessibilityTraits = selected ? [.button, .selected] : .button
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateSelectionBorderColor()
        }
    }

    private func updateSelectionBorderColor() {
        containerView.layer.borderColor = UIColor.label.resolvedColor(with: traitCollection).cgColor
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        rowView.reset()
        accessibilityLabel = nil
    }

    // MARK: - Configure

    func configure(with item: MonthItem) {
        let total = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentPhotoCount

        let notStartedSubtitle = item.mediaType == .video
            ? Strings.videosToReview(item.currentPhotoCount)
            : Strings.photosToReview(item.currentPhotoCount)

        rowView.configure(
            title: item.title,
            deleted: item.deletedCount,
            kept: item.keptCount,
            stored: item.storedCount,
            total: total,
            reviewed: item.reviewedCount,
            notStartedSubtitle: notStartedSubtitle)
        accessibilityLabel = rowView.accessibilitySummary
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

private enum MonthListCellPreview {
    static func item(
        _ title: String, total: Int, reviewed: Int = 0, deleted: Int = 0, kept: Int = 0, stored: Int = 0,
        mediaType: PHAssetMediaType = .image
    ) -> MonthItem {
        MonthItem(
            title: title, key: "2026-09", currentPhotoCount: total, reviewedCount: reviewed,
            keptCount: kept, deletedCount: deleted, storedCount: stored, originalTotalCount: total,
            mediaType: mediaType)
    }

    static let items: [MonthItem] = [
        item("September 2026", total: 29),
        item("August 2026", total: 92, reviewed: 63, deleted: 20, kept: 38, stored: 5),
        item("July 2026", total: 40, reviewed: 12, deleted: 12),
        item("June 2026", total: 150, reviewed: 150, deleted: 100, kept: 50),
        item("May 2026", total: 12_345, reviewed: 9_876, deleted: 4_321, kept: 5_000, stored: 555),
        item("April 2026", total: 2_000, reviewed: 1, deleted: 1)
    ]

    /// Every state, one cell under another
    static func stack() -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.backgroundColor = .mainBackground
        items.forEach { item in
            let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
            cell.configure(with: item)
            stack.addArrangedSubview(cell)
        }
        return stack
    }
}

@available(iOS 17.0, *)
#Preview("All states · 320", traits: .fixedLayout(width: 320, height: 520)) {
    MonthListCellPreview.stack()
}

@available(iOS 17.0, *)
#Preview("All states · 375", traits: .fixedLayout(width: 375, height: 520)) {
    MonthListCellPreview.stack()
}

@available(iOS 17.0, *)
#Preview("All states · 430", traits: .fixedLayout(width: 430, height: 520)) {
    MonthListCellPreview.stack()
}
#endif

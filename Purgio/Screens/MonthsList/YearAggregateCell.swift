//
//  YearAggregateCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 25.06.2026.
//

import Photos
import UIKit

final class YearAggregateCell: UITableViewCell {

    static let reuseIdentifier = "YearAggregateCell"

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

    private static let monthAbbrevFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
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
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: YearAggregateCell, _: UITraitCollection) in
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

    func configure(with item: YearItem) {
        let total = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentTotalCount

        rowView.configure(
            title: item.year,
            titleFont: ThemeManager.Fonts.titleFont(size: 17, weight: .bold),
            deleted: item.deletedCount,
            kept: item.keptCount,
            stored: item.storedCount,
            total: total,
            reviewed: item.reviewedCount,
            notStartedSubtitle: notStartedSubtitle(for: item))
        accessibilityLabel = rowView.accessibilitySummary
    }

    /// "Jan, Jul, Nov · 23 items"
    private func notStartedSubtitle(for item: YearItem) -> String {
        let monthNames = item.months.compactMap { month -> String? in
            guard let date = DateFormatterManager.shared.date(fromMonthKey: month.key) else { return nil }
            return Self.monthAbbrevFormatter.string(from: date)
        }.joined(separator: ", ")

        let countText = String(
            format: NSLocalizedString("yearCell.itemsCount", comment: ""),
            item.currentTotalCount)

        return monthNames.isEmpty ? countText : "\(monthNames) · \(countText)"
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview("Not Started", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = YearAggregateCell(style: .default, reuseIdentifier: "cell")
    cell.configure(with: YearItem(
        year: "2015", key: "year-2015",
        months: [
            MonthItem(title: "January 2015", key: "2015-01", currentPhotoCount: 8,  reviewedCount: 0, keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: 8,  mediaType: .image),
            MonthItem(title: "July 2015",    key: "2015-07", currentPhotoCount: 10, reviewedCount: 0, keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: 10, mediaType: .image),
            MonthItem(title: "November 2015",key: "2015-11", currentPhotoCount: 5,  reviewedCount: 0, keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: 5,  mediaType: .image),
        ],
        currentTotalCount: 23, reviewedCount: 0, deletedCount: 0, keptCount: 0, storedCount: 0, originalTotalCount: 23, mediaType: .image))
    return cell
}

@available(iOS 17.0, *)
#Preview("In Progress", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = YearAggregateCell(style: .default, reuseIdentifier: "cell")
    cell.configure(with: YearItem(
        year: "2015", key: "year-2015", months: [],
        currentTotalCount: 23, reviewedCount: 14, deletedCount: 8, keptCount: 5, storedCount: 1, originalTotalCount: 23, mediaType: .image))
    return cell
}

@available(iOS 17.0, *)
#Preview("Fully Reviewed", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = YearAggregateCell(style: .default, reuseIdentifier: "cell")
    cell.configure(with: YearItem(
        year: "2015", key: "year-2015", months: [],
        currentTotalCount: 23, reviewedCount: 23, deletedCount: 15, keptCount: 7, storedCount: 1, originalTotalCount: 23, mediaType: .image))
    return cell
}

@available(iOS 17.0, *)
#Preview("Large numbers (K)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = YearAggregateCell(style: .default, reuseIdentifier: "cell")
    cell.configure(with: YearItem(
        year: "2023", key: "year-2023", months: [],
        currentTotalCount: 5000, reviewedCount: 3200, deletedCount: 1200, keptCount: 1500, storedCount: 500, originalTotalCount: 5000, mediaType: .image))
    return cell
}
#endif

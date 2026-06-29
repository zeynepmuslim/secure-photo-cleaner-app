//
//  YearAggregateCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 25.06.2026.
//

import Photos
import SwiftUI
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

    private let progressBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .progressInProgress
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: 17, weight: .bold)
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let detailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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

    private let reviewedStat = StatItemView()
    private let deletedStat = StatItemView()
    private let keptStat = StatItemView()
    private let storedStat = StatItemView()

    private var progressWidthConstraint: NSLayoutConstraint?

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(containerView)
        containerView.addSubview(progressBackgroundView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(detailLabel)
        containerView.addSubview(chevronImageView)
        containerView.addSubview(statsStackView)

        statsStackView.addArrangedSubview(reviewedStat)
        statsStackView.addArrangedSubview(deletedStat)
        statsStackView.addArrangedSubview(keptStat)
        statsStackView.addArrangedSubview(storedStat)
    }

    private func setupConstraints() {
        reviewedStat.translatesAutoresizingMaskIntoConstraints = false
        deletedStat.translatesAutoresizingMaskIntoConstraints = false
        keptStat.translatesAutoresizingMaskIntoConstraints = false
        storedStat.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            deletedStat.widthAnchor.constraint(equalTo: keptStat.widthAnchor),
            keptStat.widthAnchor.constraint(equalTo: storedStat.widthAnchor),
            reviewedStat.widthAnchor.constraint(equalTo: deletedStat.widthAnchor, multiplier: 1.7),

            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            progressBackgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            progressBackgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            progressBackgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -32),

            chevronImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            chevronImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            chevronImageView.widthAnchor.constraint(equalToConstant: 12),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            detailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -36),
            detailLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),

            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            statsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -36),
            statsStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            statsStackView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        progressBackgroundView.backgroundColor = .clear
        removeProgressConstraint()
    }

    private func removeProgressConstraint() {
        progressWidthConstraint?.isActive = false
        progressWidthConstraint = nil
    }

    // MARK: - Configuration
    func configure(with item: YearItem) {
        titleLabel.text = item.year

        let total = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentTotalCount
        let reviewed = item.reviewedCount

        removeProgressConstraint()

        if total > 0 && reviewed >= total {
            configureFullyReviewed()
        } else if reviewed == 0 {
            configureNotStarted(item: item)
        } else {
            configureInProgress(item: item, total: total)
        }
    }

    private func configureFullyReviewed() {
        detailLabel.isHidden = false
        statsStackView.isHidden = true

        progressBackgroundView.backgroundColor = .progressCompleted
        progressWidthConstraint = progressBackgroundView.widthAnchor.constraint(
            equalTo: containerView.widthAnchor)
        progressWidthConstraint?.isActive = true

        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.Colors.statusGreen,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ]
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: config)?
            .withTintColor(ThemeManager.Colors.statusGreen)
        {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
            let attributed = NSMutableAttributedString(attachment: attachment)
            attributed.append(NSAttributedString(
                string: "  " + NSLocalizedString("monthsList.yearDone", comment: ""),
                attributes: textAttributes))
            detailLabel.attributedText = attributed
        } else {
            detailLabel.attributedText = NSAttributedString(
                string: NSLocalizedString("monthsList.yearDone", comment: ""),
                attributes: textAttributes)
        }
    }

    private static let monthAbbrevFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private func configureNotStarted(item: YearItem) {
        detailLabel.isHidden = false
        statsStackView.isHidden = true
        progressBackgroundView.backgroundColor = .clear

        let monthNames = item.months.compactMap { month -> String? in
            guard let date = DateFormatterManager.shared.date(fromMonthKey: month.key) else { return nil }
            return Self.monthAbbrevFormatter.string(from: date)
        }.joined(separator: ", ")

        let countText = String(
            format: NSLocalizedString("yearCell.itemsCount", comment: ""),
            item.currentTotalCount)

        let detail = monthNames.isEmpty ? countText : "\(monthNames) · \(countText)"
        detailLabel.text = detail
    }

    private func configureInProgress(item: YearItem, total: Int) {
        detailLabel.isHidden = true
        statsStackView.isHidden = false

        let color: UIColor = item.mediaType == .video ? .video50 : .photo50
        progressBackgroundView.backgroundColor = color

        let percentage = CGFloat(item.reviewedCount) / CGFloat(total)
        progressWidthConstraint = progressBackgroundView.widthAnchor.constraint(
            equalTo: containerView.widthAnchor, multiplier: percentage)
        progressWidthConstraint?.isActive = true

        let totalCount = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentTotalCount
        //Actually compactFormatted wont be needed bacause of bounds (50 curently)
        reviewedStat.configure(
            systemName: "eye.fill", color: .textPrimary,
            text: "\(item.reviewedCount.compactFormatted)/\(totalCount.compactFormatted)")
        deletedStat.configure(
            systemName: "trash.fill", color: ThemeManager.Colors.statusRed,
            text: item.deletedCount.compactFormatted)
        keptStat.configure(
            systemName: "checkmark.circle.fill", color: ThemeManager.Colors.statusGreen,
            text: item.keptCount.compactFormatted)
        storedStat.configure(
            systemName: "archivebox.fill", color: ThemeManager.Colors.statusYellow,
            text: item.storedCount.compactFormatted, iconPointSize: 14)
    }
}

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

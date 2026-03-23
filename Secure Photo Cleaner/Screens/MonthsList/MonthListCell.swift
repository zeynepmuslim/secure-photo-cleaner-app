//
//  MonthListCell.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import SwiftUI
import UIKit

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

    private let progressBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .progressInProgress
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraint()
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

    private func setupConstraint() {
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
        progressBackgroundView.frame.size.width = 0
        removeProgressConstraint()
    }

    private func removeProgressConstraint() {
        progressWidthConstraint?.isActive = false
        progressWidthConstraint = nil
    }

    func configure(with item: MonthItem) {
        titleLabel.text = item.title

        let total = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentPhotoCount
        let reviewed = item.reviewedCount

        removeProgressConstraint()

        if total > 0 && reviewed >= total {
            configureFullyReviewed()
        } else if reviewed == 0 {
            configureNotTouched(totalCount: item.currentPhotoCount, mediaType: item.mediaType)
        } else {
            configureInProgress(item: item, total: total)
        }
    }

    private func configureFullyReviewed() {
        detailLabel.isHidden = false
        statsStackView.isHidden = true

        progressBackgroundView.backgroundColor = .progressCompleted

        progressWidthConstraint = progressBackgroundView.widthAnchor.constraint(equalTo: containerView.widthAnchor)
        progressWidthConstraint?.isActive = true

        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: ThemeManager.Colors.statusGreen,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ]

        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        if let image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: config)?.withTintColor(
            ThemeManager.Colors.statusGreen)
        {
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: -2, width: 14, height: 14)
            let attributedString = NSMutableAttributedString(attachment: attachment)
            attributedString.append(NSAttributedString(string: "  All caught up!", attributes: textAttributes))
            detailLabel.attributedText = attributedString
        } else {
            detailLabel.attributedText = NSAttributedString(string: "All caught up!", attributes: textAttributes)
        }
    }

    private func configureNotTouched(totalCount: Int, mediaType: PHAssetMediaType) {
        detailLabel.isHidden = false
        statsStackView.isHidden = true

        progressBackgroundView.backgroundColor = .clear

        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.textSecondary,
            .font: UIFont.systemFont(ofSize: 13, weight: .regular)
        ]

        let typeString = mediaType == .video ? "videos" : "photos"
        detailLabel.attributedText = NSAttributedString(
            string: "\(totalCount) \(typeString) to review", attributes: textAttributes)
    }

    private func configureInProgress(item: MonthItem, total: Int) {
        detailLabel.isHidden = true
        statsStackView.isHidden = false

        let color =
            item.mediaType == .video
            ? UIColor.video50
            : UIColor.photo50
        progressBackgroundView.backgroundColor = color

        let percentage = CGFloat(item.reviewedCount) / CGFloat(total)

        progressWidthConstraint = progressBackgroundView.widthAnchor.constraint(
            equalTo: containerView.widthAnchor, multiplier: percentage)
        progressWidthConstraint?.isActive = true

        let totalCount = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentPhotoCount

        reviewedStat.configure(
            systemName: "eye.fill", color: .textPrimary, text: "\(item.reviewedCount)/\(totalCount)")
        deletedStat.configure(
            systemName: "trash.fill", color: ThemeManager.Colors.statusRed, text: "\(item.deletedCount)")
        keptStat.configure(
            systemName: "checkmark.circle.fill", color: ThemeManager.Colors.statusGreen, text: "\(item.keptCount)")
        storedStat.configure(
            systemName: "archivebox.fill", color: ThemeManager.Colors.statusYellow, text: "\(item.storedCount)", iconPointSize: 14)
    }
}

@available(iOS 17.0, *)
#Preview("Photos (Untouched)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
    let item = MonthItem(
        title: "September 2024",
        key: "202409",
        currentPhotoCount: 100,
        reviewedCount: 0,
        keptCount: 0,
        deletedCount: 0,
        storedCount: 0,
        originalTotalCount: 100,
        mediaType: .image
    )
    cell.configure(with: item)
    return cell
}

@available(iOS 17.0, *)
#Preview("Photos (In Progress)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
    let item = MonthItem(
        title: "January 2024",
        key: "202401",
        currentPhotoCount: 100,
        reviewedCount: 30,
        keptCount: 10,
        deletedCount: 20,
        storedCount: 0,
        originalTotalCount: 100,
        mediaType: .image
    )
    cell.configure(with: item)
    return cell
}

@available(iOS 17.0, *)
#Preview("Photos (Finished)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
    let item = MonthItem(
        title: "March 2024",
        key: "202403",
        currentPhotoCount: 150,
        reviewedCount: 150,
        keptCount: 50,
        deletedCount: 100,
        storedCount: 0,
        originalTotalCount: 150,
        mediaType: .image
    )
    cell.configure(with: item)
    return cell
}

@available(iOS 17.0, *)
#Preview("Videos (Untouched)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
    let item = MonthItem(
        title: "February 2024",
        key: "202402",
        currentPhotoCount: 50,
        reviewedCount: 0,
        keptCount: 0,
        deletedCount: 0,
        storedCount: 0,
        originalTotalCount: 50,
        mediaType: .video
    )
    cell.configure(with: item)
    return cell
}

@available(iOS 17.0, *)
#Preview("Videos (In Progress)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
    let item = MonthItem(
        title: "June 2024",
        key: "202406",
        currentPhotoCount: 40,
        reviewedCount: 20,
        keptCount: 10,
        deletedCount: 10,
        storedCount: 0,
        originalTotalCount: 40,
        mediaType: .video
    )
    cell.configure(with: item)
    return cell
}

@available(iOS 17.0, *)
#Preview("Videos (Finished)", traits: .fixedLayout(width: 375, height: 90)) {
    let cell = MonthListCell(style: .default, reuseIdentifier: "cell")
    let item = MonthItem(
        title: "April 2024",
        key: "202404",
        currentPhotoCount: 20,
        reviewedCount: 20,
        keptCount: 5,
        deletedCount: 15,
        storedCount: 0,
        originalTotalCount: 20,
        mediaType: .video
    )
    cell.configure(with: item)
    return cell
}

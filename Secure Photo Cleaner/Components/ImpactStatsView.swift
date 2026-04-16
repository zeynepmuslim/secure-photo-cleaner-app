//
//  ImpactStatsView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 22.03.2026.
//

import UIKit

final class ImpactStatsView: UIView {

    private enum Strings {
        static let spaceSaved = NSLocalizedString("impactStats.spaceSaved", comment: "Space saved stat label")
        static let itemsStored = NSLocalizedString("impactStats.itemsStored", comment: "Items stored stat label")
        static let totalReviewed = NSLocalizedString("impactStats.totalReviewed", comment: "Total reviewed stat label")
        static let photos = NSLocalizedString("impactStats.photos", comment: "Photos label")
        static let videos = NSLocalizedString("impactStats.videos", comment: "Videos label")
        static let emptyStats = NSLocalizedString("impactStats.emptyStats", comment: "Empty state message for impact stats")

        static func reviewedDeleted(reviewed: Int, deleted: Int) -> String {
            String(format: NSLocalizedString("impactStats.reviewedDeleted", comment: "Stats summary, e.g. '5 reviewed • 3 deleted'"), reviewed, deleted)
        }
    }

    private let statsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }

    func update(stats: StatsStore, storedCount: Int) {
        statsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let spaceSavedRow = createStatRow(
            iconName: "sparkles",
            iconColor: .systemGreen,
            title: Strings.spaceSaved,
            value: stats.formattedSpaceSaved(),
            valueColor: .systemGreen
        )
        statsStack.addArrangedSubview(spaceSavedRow)

        statsStack.addArrangedSubview(createDivider())

        let storageRow = createStatRow(
            iconName: "archivebox.fill",
            iconColor: ThemeManager.Colors.statusYellow,
            title: Strings.itemsStored,
            value: "\(storedCount)",
            valueColor: ThemeManager.Colors.statusYellow
        )
        statsStack.addArrangedSubview(storageRow)

        statsStack.addArrangedSubview(createDivider())

        let reviewedRow = createStatRow(
            iconName: "eye",
            iconColor: .label,
            title: Strings.totalReviewed,
            value: "\(stats.totalReviewed)",
            valueColor: .label
        )
        statsStack.addArrangedSubview(reviewedRow)

        if stats.photosReviewed > 0 {
            let photosRow = createDetailRow(
                title: Strings.photos,
                reviewed: stats.photosReviewed,
                deleted: stats.photosDeleted
            )
            statsStack.addArrangedSubview(photosRow)
        }

        if stats.videosReviewed > 0 {
            let videosRow = createDetailRow(
                title: Strings.videos,
                reviewed: stats.videosReviewed,
                deleted: stats.videosDeleted
            )
            statsStack.addArrangedSubview(videosRow)
        }

        if stats.totalReviewed == 0 {
            let emptyLabel = UILabel()
            emptyLabel.text = Strings.emptyStats
            emptyLabel.font = .systemFont(ofSize: 14, weight: .medium)
            emptyLabel.textColor = .systemGray
            emptyLabel.numberOfLines = 0
            emptyLabel.textAlignment = .center
            statsStack.addArrangedSubview(emptyLabel)
        }
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(statsStack)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            statsStack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            statsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            statsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            statsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20)
        ])
    }

    private func createStatRow(iconName: String, iconColor: UIColor, title: String, value: String, valueColor: UIColor)
        -> UIView
    {
        let container = UIView()

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: iconName, withConfiguration: iconConfig)
        iconView.tintColor = iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = valueColor
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
        ])

        return container
    }

    private func createDetailRow(title: String, reviewed: Int, deleted: Int) -> UIView {
        let container = UIView()

        let titleLabel = UILabel()
        titleLabel.text = "  \u{2022} \(title)"   // unicode of •
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = .systemGray
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = Strings.reviewedDeleted(reviewed: reviewed, deleted: deleted)
        valueLabel.font = .systemFont(ofSize: 13, weight: .medium)
        valueLabel.textColor = .systemGray2
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            valueLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
        ])

        return container
    }

    private func createDivider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }
}

@available(iOS 17.0, *)
#Preview {
    let view = ImpactStatsView()
    view.update(stats: StatsStore.shared, storedCount: WillBeStoredStore.shared.count)

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(view)
    NSLayoutConstraint.activate([
        view.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
        view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
    ])
    return container
}

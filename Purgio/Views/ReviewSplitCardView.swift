//
//  ReviewSplitCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let delete = CommonStrings.delete
    static let keep = CommonStrings.keep
    static let store = CommonStrings.store
    static func accessibility(deleted: Int, kept: Int, stored: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("reviewSplit.accessibility", comment: "VoiceOver label of a finished month's split: delete, keep, store counts"),
            deleted, kept, stored)
    }
}

/// A finished month's split: a delete / keep / store bar over the three counts, each a colored
/// icon, the count and the name. The names hide when the row is too narrow for them.
/// MonthReview's completion state shows it as its `EmptyStateView` accessory.
final class ReviewSplitCardView: UIView {
    private enum Layout {
        static let verticalInset = GeneralConstants.EdgePadding.cardInner
        static let horizontalInset = GeneralConstants.EdgePadding.cardInner
        static let barHeight: CGFloat = 12
        static let barToItems: CGFloat = 14
        static let iconPointSize: CGFloat = 14
        static let countSize: CGFloat = 15
        static let nameSize: CGFloat = 13
        static let itemSpacing: CGFloat = 6
        /// The least room between two items for the names to stay
        static let minimumItemGap: CGFloat = 8
    }

    private final class ItemView: UIStackView {
        let countLabel = UILabel()
        let nameLabel = UILabel()

        init(systemImage: String, color: UIColor, name: String) {
            super.init(frame: .zero)
            axis = .horizontal
            alignment = .center
            spacing = Layout.itemSpacing

            let config = UIImage.SymbolConfiguration(pointSize: Layout.iconPointSize, weight: .semibold)
            let icon = UIImageView(image: UIImage(systemName: systemImage, withConfiguration: config))
            icon.tintColor = color
            icon.setContentHuggingPriority(.required, for: .horizontal)

            countLabel.font = .monospacedDigitSystemFont(ofSize: Layout.countSize, weight: .bold)
            countLabel.textColor = .textPrimary
            nameLabel.font = .systemFont(ofSize: Layout.nameSize, weight: .regular)
            nameLabel.textColor = .textSecondary
            nameLabel.text = name

            [icon, countLabel, nameLabel].forEach { addArrangedSubview($0) }
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// The item's width with its name showing, whether or not it is
        var widthWithName: CGFloat {
            let wasHidden = nameLabel.isHidden
            nameLabel.isHidden = false
            let width = systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
            nameLabel.isHidden = wasHidden
            return width
        }
    }

    private let barView: SegmentedBarView = {
        let bar = SegmentedBarView()
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    private let deleteItem = ItemView(systemImage: "trash", color: ThemeManager.Colors.statusRed, name: Strings.delete)
    private let keepItem = ItemView(systemImage: "checkmark", color: ThemeManager.Colors.statusGreen, name: Strings.keep)
    private let storeItem = ItemView(systemImage: "archivebox", color: ThemeManager.Colors.statusYellow, name: Strings.store)

    private let itemsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var items: [ItemView] { [deleteItem, keepItem, storeItem] }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        addSubview(barView)
        addSubview(itemsStack)
        items.forEach { itemsStack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            barView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalInset),
            barView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalInset),
            barView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalInset),
            barView.heightAnchor.constraint(equalToConstant: Layout.barHeight),

            itemsStack.topAnchor.constraint(equalTo: barView.bottomAnchor, constant: Layout.barToItems),
            itemsStack.leadingAnchor.constraint(equalTo: barView.leadingAnchor),
            itemsStack.trailingAnchor.constraint(equalTo: barView.trailingAnchor),
            itemsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalInset)
        ])

        isAccessibilityElement = true
    }

    func configure(deleted: Int, kept: Int, stored: Int) {
        let total = max(1, deleted + kept + stored)
        var segments: [SegmentedBarView.Segment] = []
        if deleted > 0 {
            segments.append(.init(color: ThemeManager.Colors.statusRed, percentage: CGFloat(deleted) / CGFloat(total)))
        }
        if kept > 0 {
            segments.append(.init(color: ThemeManager.Colors.statusGreen, percentage: CGFloat(kept) / CGFloat(total)))
        }
        if stored > 0 {
            segments.append(.init(color: ThemeManager.Colors.statusYellow, percentage: CGFloat(stored) / CGFloat(total)))
        }
        barView.configure(segments: segments, animated: false)

        deleteItem.countLabel.text = deleted.compactFormatted
        keepItem.countLabel.text = kept.compactFormatted
        storeItem.countLabel.text = stored.compactFormatted
        accessibilityLabel = Strings.accessibility(deleted: deleted, kept: kept, stored: stored)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Names show only while the three items fit the row with them
        let available = itemsStack.bounds.width
        guard available > 0 else { return }
        let needed = items.reduce(0) { $0 + $1.widthWithName } + 2 * Layout.minimumItemGap
        let showsNames = needed <= available
        items.forEach { item in
            if item.nameLabel.isHidden == showsNames { item.nameLabel.isHidden = !showsNames }
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let card = ReviewSplitCardView()
    card.configure(deleted: 21, kept: 63, stored: 8)
    card.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(card)
    NSLayoutConstraint.activate([
        card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        card.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}
#endif

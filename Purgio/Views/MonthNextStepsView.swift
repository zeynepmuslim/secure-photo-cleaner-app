//
//  MonthNextStepsView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static func keepGoing(in month: String) -> String {
        String(format: NSLocalizedString("nextSteps.keepGoing", comment: "Label over a month's unfinished filters, e.g. 'Keep going in August 2025'"), month)
    }
}

/// The end states' "Keep going in <month>" list: a label over a card of the month's unfinished
/// filters, each a `FilterCard` row with the hub's capsule and status (FilterType+Route).
/// At most three rows, All Photos last. An `EmptyStateView` accessory.
final class MonthNextStepsView: UIView {
    private enum Layout {
        static let maximumRows = 3
        static let rowHeight: CGFloat = 56
        static let labelSize: CGFloat = 13
        static let labelInset: CGFloat = 4
        static let labelToCard: CGFloat = 8
        /// Where a separator starts: past the row's icon, level with its title
        static let separatorInset: CGFloat = 56
    }

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.labelSize, weight: .semibold)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        label.accessibilityTraits = .header
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = GeneralConstants.CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let rowsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var rowFilters: [(card: FilterCard, filter: MonthFilterStatusStore.FilterType)] = []

    /// A row was tapped; the host replaces itself with that filter's screen.
    var onSelect: ((MonthFilterStatusStore.FilterType) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(cardView)
        cardView.addSubview(rowsStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.labelInset),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.labelInset),

            cardView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.labelToCard),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor),

            rowsStack.topAnchor.constraint(equalTo: cardView.topAnchor),
            rowsStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            rowsStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            rowsStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
    }

    /// The filters this month still has open, in the hub's order, without `current`: at most
    /// three, and All Photos / All Videos always the last one when it's open. Year sessions
    /// have no list (their filters need the hub's preloaded assets).
    static func openFilters(
        monthKey: String, mediaType: PHAssetMediaType, excluding current: MonthFilterStatusStore.FilterType?
    ) -> [MonthFilterStatusStore.FilterType] {
        guard !monthKey.hasPrefix("year-") else { return [] }
        let open = MonthFilterStatusStore.FilterType.hubOrder(for: mediaType).filter {
            $0 != current && !$0.isComplete(monthKey: monthKey, mediaType: mediaType)
        }
        guard open.count > Layout.maximumRows else { return open }
        if open.last == .allContent {
            return Array(open.prefix(Layout.maximumRows - 1)) + [.allContent]
        }
        return Array(open.prefix(Layout.maximumRows))
    }

    /// Builds the rows. Returns false when the month has nothing left to offer; the host then
    /// shows no accessory.
    @discardableResult
    func configure(
        monthTitle: String, monthKey: String, mediaType: PHAssetMediaType,
        excluding current: MonthFilterStatusStore.FilterType?
    ) -> Bool {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        rowFilters = []

        let filters = Self.openFilters(monthKey: monthKey, mediaType: mediaType, excluding: current)
        guard !filters.isEmpty else { return false }

        titleLabel.text = Strings.keepGoing(in: monthTitle)

        for (index, filter) in filters.enumerated() {
            if index > 0 {
                rowsStack.addArrangedSubview(makeSeparator())
            }
            let card = FilterCard()
            card.configure(
                icon: filter.cardIcon(mediaType: mediaType),
                title: filter.cardTitle(mediaType: mediaType),
                tintColor: filter.cardTint(mediaType: mediaType),
                style: .row)
            filter.applyStatus(to: card, monthKey: monthKey, mediaType: mediaType)
            // The list's card rounds the corners; the rows are flat inside it
            card.layer.cornerRadius = 0
            card.addTarget(self, action: #selector(rowTapped(_:)), for: .touchUpInside)
            NSLayoutConstraint.activate([card.heightAnchor.constraint(equalToConstant: Layout.rowHeight)])
            rowsStack.addArrangedSubview(card)
            rowFilters.append((card, filter))
        }
        return true
    }

    private func makeSeparator() -> UIView {
        let container = UIView()
        container.backgroundColor = .cardBackground
        let line = UIView()
        line.backgroundColor = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(line)
        let hairline = 1 / max(1, traitCollection.displayScale)
        NSLayoutConstraint.activate([
            container.heightAnchor.constraint(equalToConstant: hairline),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: Layout.separatorInset),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    @objc private func rowTapped(_ sender: FilterCard) {
        guard let filter = rowFilters.first(where: { $0.card === sender })?.filter else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        onSelect?(filter)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let list = MonthNextStepsView()
    list.configure(monthTitle: "August 2025", monthKey: "2025-08", mediaType: .image, excluding: .screenshots)
    list.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(list)
    NSLayoutConstraint.activate([
        list.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        list.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        list.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}
#endif

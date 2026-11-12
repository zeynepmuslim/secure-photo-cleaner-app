//
//  ImpactTilesView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// Settings' impact numbers as one card (board H1 · big numbers), used by every Settings
/// layout. The space saved leads on the left; the stored and reviewed counts sit in a column
/// on the right, past a hairline. Same numbers as `ImpactStatsView`.
///
/// The counts never truncate: they're compact (`Int.compactFormatted`, at most 4 characters)
/// and the right column resists compression, so the saved value shrinks instead. When even
/// that isn't enough for the card's own width, the card stacks: the saved value on top, a
/// hairline, then the two counts side by side.
final class ImpactTilesView: UIView {

    // MARK: - Strings
    private enum Strings {
        static let spaceSaved = NSLocalizedString("impactStats.spaceSaved", comment: "Space saved stat label")
        static let itemsStored = NSLocalizedString("impactStats.itemsStored", comment: "Items stored stat label")
        static let totalReviewed = NSLocalizedString("impactStats.totalReviewed", comment: "Total reviewed stat label")
    }

    private enum Layout {
        /// Settings cards' inner padding
        static let padding: CGFloat = 18
        static let minimumHeight: CGFloat = 112
        static let separatorGap: CGFloat = 16
        static let separatorWidth: CGFloat = 1
        static let rowSpacing: CGFloat = 14
        static let iconSize: CGFloat = 24
        static let iconToValue: CGFloat = 6
        static let valueToTitle: CGFloat = 2
        static let savedFontSize: CGFloat = 34
        static let savedMinimumScale: CGFloat = 0.6
        static let titleMinimumScale: CGFloat = 0.8
    }

    private enum Arrangement {
        case sideBySide
        case stacked
    }

    // MARK: - Views

    private let savedIconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        imageView.image = UIImage(systemName: "sparkles", withConfiguration: config)
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let savedValueLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: Layout.savedFontSize, weight: .bold)
        label.textColor = .systemGreen
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = Layout.savedMinimumScale
        label.baselineAdjustment = .alignBaselines
        // Gives way first, so the counts keep their full size
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let savedTitleLabel: UILabel = ImpactTilesView.makeTitleLabel(text: Strings.spaceSaved)

    /// The icon at the top, the value and its title at the bottom
    private let savedColumn: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }()

    private let verticalSeparator: UIView = ImpactTilesView.makeSeparator()
    private let horizontalSeparator: UIView = ImpactTilesView.makeSeparator()

    private let storedRow = ImpactCountRow(
        iconName: "archivebox.fill", tintColor: ThemeManager.Colors.statusYellow, title: Strings.itemsStored)
    private let reviewedRow = ImpactCountRow(
        iconName: "eye", tintColor: .label, title: Strings.totalReviewed)

    private let countsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.rowSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.required, for: .horizontal)
        return stack
    }()

    // MARK: - State

    private var arrangement: Arrangement = .sideBySide
    private var sideBySideConstraints: [NSLayoutConstraint] = []
    private var stackedConstraints: [NSLayoutConstraint] = []
    /// Lines the counts' numbers up in one column while side by side
    private var equalNumberWidths: NSLayoutConstraint?

    private var savedText = ""
    private var storedCount = 0
    private var reviewedCount = 0

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    func configure(spaceSaved: String, storedCount: Int, reviewedCount: Int) {
        savedText = spaceSaved
        self.storedCount = storedCount
        self.reviewedCount = reviewedCount
        savedValueLabel.text = spaceSaved
        storedRow.setValue(storedCount.compactFormatted)
        reviewedRow.setValue(reviewedCount.compactFormatted)
        updateAccessibilityLabel()
        // The fit depends on the text, so check it again
        setNeedsLayout()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        applyArrangement(fittingArrangement())
        super.layoutSubviews()
    }

    /// Side by side unless the counts at full size, the separator and the saved column at its
    /// smallest don't fit the card's own width
    private func fittingArrangement() -> Arrangement {
        let available = bounds.width - 2 * Layout.padding
        guard available > 0 else { return arrangement }
        let numberWidth = max(storedRow.numberFittingWidth, reviewedRow.numberFittingWidth)
        let countsWidth = max(storedRow.inlineWidth(numberWidth: numberWidth),
                              reviewedRow.inlineWidth(numberWidth: numberWidth))
        let savedMinimum = max(
            Layout.iconSize,
            savedValueLabel.textFittingWidth * Layout.savedMinimumScale,
            savedTitleLabel.textFittingWidth * Layout.titleMinimumScale)
        let needed = savedMinimum + 2 * Layout.separatorGap + Layout.separatorWidth + countsWidth
        return needed > available ? .stacked : .sideBySide
    }

    private func applyArrangement(_ newArrangement: Arrangement) {
        guard newArrangement != arrangement else { return }
        arrangement = newArrangement
        let stacked = newArrangement == .stacked

        NSLayoutConstraint.deactivate(stacked ? sideBySideConstraints : stackedConstraints)
        NSLayoutConstraint.activate(stacked ? stackedConstraints : sideBySideConstraints)
        equalNumberWidths?.isActive = !stacked
        verticalSeparator.isHidden = stacked
        horizontalSeparator.isHidden = !stacked
        countsStack.axis = stacked ? .horizontal : .vertical
        countsStack.distribution = stacked ? .fillEqually : .fill
        countsStack.alignment = stacked ? .top : .leading
        countsStack.spacing = stacked ? Layout.separatorGap : Layout.rowSpacing
        [storedRow, reviewedRow].forEach { $0.setTitleBelow(stacked) }
        // The card's height changes with the arrangement
        superview?.setNeedsLayout()
    }

    // MARK: - Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        isAccessibilityElement = true

        [savedIconView, savedValueLabel, savedTitleLabel].forEach { savedColumn.addSubview($0) }
        [storedRow, reviewedRow].forEach { countsStack.addArrangedSubview($0) }
        [savedColumn, verticalSeparator, horizontalSeparator, countsStack].forEach { addSubview($0) }
        horizontalSeparator.isHidden = true
    }

    private func setupConstraint() {
        let padding = Layout.padding

        // The saved column: icon at the top, the value and title at the bottom, the gap between
        // grows when the card does
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumHeight),

            savedIconView.topAnchor.constraint(equalTo: savedColumn.topAnchor),
            savedIconView.leadingAnchor.constraint(equalTo: savedColumn.leadingAnchor),
            savedIconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            savedIconView.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            savedValueLabel.topAnchor.constraint(
                greaterThanOrEqualTo: savedIconView.bottomAnchor, constant: Layout.iconToValue),
            savedValueLabel.leadingAnchor.constraint(equalTo: savedColumn.leadingAnchor),
            savedValueLabel.trailingAnchor.constraint(lessThanOrEqualTo: savedColumn.trailingAnchor),

            savedTitleLabel.topAnchor.constraint(equalTo: savedValueLabel.bottomAnchor, constant: Layout.valueToTitle),
            savedTitleLabel.leadingAnchor.constraint(equalTo: savedColumn.leadingAnchor),
            savedTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: savedColumn.trailingAnchor),
            savedTitleLabel.bottomAnchor.constraint(equalTo: savedColumn.bottomAnchor),

            verticalSeparator.widthAnchor.constraint(equalToConstant: Layout.separatorWidth),
            horizontalSeparator.heightAnchor.constraint(equalToConstant: Layout.separatorWidth)
        ])

        sideBySideConstraints = [
            savedColumn.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            savedColumn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            savedColumn.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),

            verticalSeparator.leadingAnchor.constraint(
                equalTo: savedColumn.trailingAnchor, constant: Layout.separatorGap),
            verticalSeparator.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            verticalSeparator.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),

            countsStack.leadingAnchor.constraint(
                equalTo: verticalSeparator.trailingAnchor, constant: Layout.separatorGap),
            countsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            countsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            countsStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: padding),
            countsStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -padding)
        ]

        stackedConstraints = [
            savedColumn.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            savedColumn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            savedColumn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),

            horizontalSeparator.topAnchor.constraint(
                equalTo: savedColumn.bottomAnchor, constant: Layout.rowSpacing),
            horizontalSeparator.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            horizontalSeparator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),

            countsStack.topAnchor.constraint(
                equalTo: horizontalSeparator.bottomAnchor, constant: Layout.rowSpacing),
            countsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            countsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            countsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ]

        equalNumberWidths = storedRow.numberLabel.widthAnchor.constraint(
            equalTo: reviewedRow.numberLabel.widthAnchor)

        // Side by side until the first layout pass says otherwise
        NSLayoutConstraint.activate(sideBySideConstraints)
        equalNumberWidths?.isActive = true
    }

    private func updateAccessibilityLabel() {
        accessibilityLabel = "\(Strings.spaceSaved) \(savedText), "
            + "\(Strings.itemsStored) \(storedCount), \(Strings.totalReviewed) \(reviewedCount)"
    }

    // MARK: - Factories

    fileprivate static func makeTitleLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = Layout.titleMinimumScale
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func makeSeparator() -> UIView {
        let view = UIView()
        view.backgroundColor = .separator
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
}

// MARK: - ImpactCountRow

/// One count: icon, number, title in a line, or (stacked) the title under the number.
private final class ImpactCountRow: UIView {

    private enum Layout {
        static let iconSize: CGFloat = 22
        static let gap: CGFloat = 8
        static let titleBelowSpacing: CGFloat = 2
    }

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 20, weight: .bold)
        label.numberOfLines = 1
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel

    private var inlineConstraints: [NSLayoutConstraint] = []
    private var belowConstraints: [NSLayoutConstraint] = []

    init(iconName: String, tintColor: UIColor, title: String) {
        titleLabel = ImpactTilesView.makeTitleLabel(text: title)
        super.init(frame: .zero)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: config)
        iconView.tintColor = tintColor
        numberLabel.textColor = tintColor
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: String) {
        numberLabel.text = value
    }

    var numberFittingWidth: CGFloat { numberLabel.textFittingWidth }

    /// The row's width in one line, at full size, with the number column `numberWidth` wide
    func inlineWidth(numberWidth: CGFloat) -> CGFloat {
        Layout.iconSize + Layout.gap + numberWidth + Layout.gap + titleLabel.textFittingWidth
    }

    func setTitleBelow(_ below: Bool) {
        NSLayoutConstraint.deactivate(below ? inlineConstraints : belowConstraints)
        NSLayoutConstraint.activate(below ? belowConstraints : inlineConstraints)
        // Inline the title keeps its full size; below it may shrink into the half width
        titleLabel.setContentCompressionResistancePriority(
            below ? .defaultLow : .required, for: .horizontal)
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        [iconView, numberLabel, titleLabel].forEach { addSubview($0) }
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: numberLabel.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            numberLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: Layout.gap),
            numberLabel.topAnchor.constraint(equalTo: topAnchor)
        ])

        inlineConstraints = [
            titleLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: Layout.gap),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.firstBaselineAnchor.constraint(equalTo: numberLabel.firstBaselineAnchor),
            numberLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        belowConstraints = [
            numberLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            titleLabel.topAnchor.constraint(
                equalTo: numberLabel.bottomAnchor, constant: Layout.titleBelowSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: numberLabel.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ]
        NSLayoutConstraint.activate(inlineConstraints)
    }
}

// MARK: - UILabel fitting width

private extension UILabel {
    /// The text's one-line width at the label's full font size
    var textFittingWidth: CGFloat {
        guard let text, let font else { return 0 }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let states: [(String, Int, Int)] = [
        ("48 MB", 1, 12),
        ("248.63 GB", 4812, 31407),
        ("1.24 TB", 12345, 128904)
    ]
    let widths: [CGFloat] = [335, 362, 400]

    let stack = UIStackView()
    stack.axis = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    for width in widths {
        for (saved, stored, reviewed) in states {
            let card = ImpactTilesView()
            card.configure(spaceSaved: saved, storedCount: stored, reviewedCount: reviewed)
            stack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
    }

    let scrollView = UIScrollView()
    scrollView.backgroundColor = .mainBackground
    scrollView.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
        stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
        stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
        stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16)
    ])
    return scrollView
}
#endif

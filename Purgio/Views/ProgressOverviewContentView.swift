//
//  ProgressOverviewContentView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let leftCaption = NSLocalizedString(
        "filterCards.leftCaption", comment: "Caption over the number of items left: Left")
    static func percent(_ value: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("filterCards.percent", comment: "Percent reviewed: 9%"), value)
    }
    static func reviewedFraction(reviewed: Int, total: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("filterCards.reviewedFraction", comment: "Reviewed / total: 8 / 92"),
            reviewed, total)
    }
    static func accessibility(_ state: ProgressOverviewState) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString(
                "filterCards.overviewAccessibility",
                comment: "VoiceOver label of the overview card: left, percent, reviewed, total, delete, keep, store"),
            state.left, state.percent, state.reviewed, state.total, state.deleted, state.kept, state.stored)
    }
    static let delete = CommonStrings.delete
    static let keep = CommonStrings.keep
    static let store = CommonStrings.store
    /// Shown while a session has no total yet
    static let placeholder = "–"
    static let placeholderFraction = "– / –"
}

/// What the month hub's overview cards show: a split capsule and, beside it, a column with two
/// rows pushed apart. On top "Left" over the number left, and the percent reviewed over
/// "8 / 92" on the trailing side; at the bottom the delete / keep / store counts spread across
/// the column. `ProgressSummaryCardView` and `ProgressOverviewView` host it.
final class ProgressOverviewContentView: UIView {

    enum Style {
        /// The one-column card: a 22pt-wide capsule as tall as the content.
        case card
        /// The Duo inner display's card: the host sets the height, the capsule is a fifth of it wide.
        case display
    }

    /// The `.card` content's height at its regular size
    static let cardContentHeight: CGFloat = 128

    private struct Metrics {
        /// nil: `capsuleWidthToHeight` of its height
        let capsuleWidth: CGFloat?
        /// nil: the host sets the content's height
        let contentHeight: CGFloat?
        let capsuleToColumn: CGFloat
        let captionFontSize: CGFloat
        let leftFontSize: CGFloat
        /// The number left in a compact content
        let compactLeftFontSize: CGFloat
        let percentFontSize: CGFloat
        let fractionFontSize: CGFloat
        let countFontSize: CGFloat
        let labelFontSize: CGFloat
        let iconPointSize: CGFloat
        let minimumItemSpacing: CGFloat

        static let card = Metrics(
            capsuleWidth: 22, contentHeight: ProgressOverviewContentView.cardContentHeight, capsuleToColumn: 16, captionFontSize: 13, leftFontSize: 40,
            compactLeftFontSize: 32,
            percentFontSize: 22, fractionFontSize: 12, countFontSize: 15, labelFontSize: 13, iconPointSize: 15,
            minimumItemSpacing: 12)
        static let display = Metrics(
            capsuleWidth: nil, contentHeight: nil, capsuleToColumn: 24, captionFontSize: 15, leftFontSize: 64,
            compactLeftFontSize: 64,
            percentFontSize: 28, fractionFontSize: 14, countFontSize: 17, labelFontSize: 15, iconPointSize: 17,
            minimumItemSpacing: 20)
    }

    private enum Layout {
        static let capsuleWidthToHeight: CGFloat = 0.2
        static let captionToNumber: CGFloat = 4
        static let topRowMinimumGap: CGFloat = 12
        static let rowsMinimumGap: CGFloat = 8
        static let itemSpacing: CGFloat = 6
    }

    /// An icon, its count and the decision's name: "trash 2 Delete". The name hides when the
    /// row is too narrow.
    private final class DecisionItemView: UIStackView {
        private let iconView = UIImageView()
        private let countLabel = UILabel()
        private let nameLabel = UILabel()

        init(systemImage: String, color: UIColor, name: String, metrics: Metrics) {
            super.init(frame: .zero)
            axis = .horizontal
            alignment = .center
            spacing = Layout.itemSpacing

            iconView.image = UIImage(
                systemName: systemImage,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: metrics.iconPointSize, weight: .semibold))
            iconView.tintColor = color
            iconView.contentMode = .scaleAspectFit
            countLabel.font = .monospacedDigitSystemFont(ofSize: metrics.countFontSize, weight: .bold)
            countLabel.textColor = .label
            nameLabel.font = .systemFont(ofSize: metrics.labelFontSize, weight: .regular)
            nameLabel.textColor = .textSecondary
            nameLabel.text = name

            [iconView, countLabel].forEach {
                $0.setContentCompressionResistancePriority(.required, for: .horizontal)
                $0.setContentHuggingPriority(.required, for: .horizontal)
            }
            [iconView, countLabel, nameLabel].forEach { addArrangedSubview($0) }
        }

        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        var count: Int = 0 {
            didSet { countLabel.text = count.compactFormatted }
        }

        var showsName: Bool {
            get { !nameLabel.isHidden }
            set { if nameLabel.isHidden == newValue { nameLabel.isHidden = !newValue } }
        }

        /// The item's width with its name, whether or not the name shows
        var widthWithName: CGFloat {
            iconView.intrinsicContentSize.width + countLabel.intrinsicContentSize.width
                + nameLabel.intrinsicContentSize.width + 2 * Layout.itemSpacing
        }
    }

    // MARK: - Views

    private let metrics: Metrics

    private let capsuleView: ReviewCapsuleView = {
        let view = ReviewCapsuleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // The numbers beside it say what's done; the capsule always shows the split
        view.alwaysShowsSplit = true
        return view
    }()

    private let columnGuide = UILayoutGuide()

    private let captionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .textSecondary
        label.text = Strings.leftCaption
        return label
    }()

    private let leftLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let percentLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        return label
    }()

    private let fractionLabel: UILabel = {
        let label = UILabel()
        label.textColor = .textSecondary
        return label
    }()

    private let leftStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = Layout.captionToNumber
        return stack
    }()

    private let reviewedStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .trailing
        stack.spacing = Layout.captionToNumber
        return stack
    }()

    private let decisionsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()

    private let deletedItem: DecisionItemView
    private let keptItem: DecisionItemView
    private let storedItem: DecisionItemView
    private var decisionItems: [DecisionItemView] { [deletedItem, keptItem, storedItem] }

    private var state: ProgressOverviewState?

    /// The widest the content may get, for a host that centers it (the content then hugs its
    /// rows, so its own width can't tell whether the names fit). nil: the column's own width.
    var maximumContentWidth: CGFloat? {
        didSet { if maximumContentWidth != oldValue { setNeedsLayout() } }
    }

    /// A short column (iPhone SE): the content is only as tall as its two rows and the number
    /// left is smaller, so the cards under it get the room. Only the `.card` style has a height
    /// of its own to give up.
    var isCompact = false {
        didSet {
            guard isCompact != oldValue else { return }
            contentHeightConstraint?.isActive = !isCompact
            let size = isCompact ? metrics.compactLeftFontSize : metrics.leftFontSize
            leftLabel.font = .monospacedDigitSystemFont(ofSize: size, weight: .heavy)
        }
    }

    private var contentHeightConstraint: NSLayoutConstraint?

    /// The whole content as one VoiceOver label; nil while the session has no total yet.
    private(set) var accessibilitySummary: String?

    // MARK: - Init

    init(style: Style) {
        let metrics: Metrics = style == .card ? .card : .display
        self.metrics = metrics
        deletedItem = DecisionItemView(
            systemImage: "trash", color: ThemeManager.Colors.statusRed, name: Strings.delete, metrics: metrics)
        keptItem = DecisionItemView(
            systemImage: "checkmark", color: ThemeManager.Colors.statusGreen, name: Strings.keep, metrics: metrics)
        storedItem = DecisionItemView(
            systemImage: "archivebox", color: ThemeManager.Colors.statusYellow, name: Strings.store, metrics: metrics)
        super.init(frame: .zero)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        captionLabel.font = .systemFont(ofSize: metrics.captionFontSize, weight: .regular)
        leftLabel.font = .monospacedDigitSystemFont(ofSize: metrics.leftFontSize, weight: .heavy)
        percentLabel.font = .monospacedDigitSystemFont(ofSize: metrics.percentFontSize, weight: .heavy)
        fractionLabel.font = .monospacedDigitSystemFont(ofSize: metrics.fractionFontSize, weight: .regular)

        leftStack.addArrangedSubview(captionLabel)
        leftStack.addArrangedSubview(leftLabel)
        reviewedStack.addArrangedSubview(percentLabel)
        reviewedStack.addArrangedSubview(fractionLabel)
        decisionItems.forEach { decisionsStack.addArrangedSubview($0) }
        decisionsStack.spacing = metrics.minimumItemSpacing

        addLayoutGuide(columnGuide)
        [capsuleView, leftStack, reviewedStack, decisionsStack].forEach { addSubview($0) }

        // The number left shrinks before the percent gives way
        leftLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        [percentLabel, fractionLabel, reviewedStack].forEach {
            $0.setContentCompressionResistancePriority(.required, for: .horizontal)
            $0.setContentHuggingPriority(.required, for: .horizontal)
        }
    }

    private func setupConstraint() {
        // Hugs its rows unless the host pins both sides
        let hugWidth = widthAnchor.constraint(equalToConstant: 0)
        hugWidth.priority = UILayoutPriority(50)

        var constraints = [
            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.topAnchor.constraint(equalTo: topAnchor),
            capsuleView.bottomAnchor.constraint(equalTo: bottomAnchor),

            columnGuide.leadingAnchor.constraint(
                equalTo: capsuleView.trailingAnchor, constant: metrics.capsuleToColumn),
            columnGuide.trailingAnchor.constraint(equalTo: trailingAnchor),
            columnGuide.topAnchor.constraint(equalTo: topAnchor),
            columnGuide.bottomAnchor.constraint(equalTo: bottomAnchor),

            leftStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            leftStack.topAnchor.constraint(equalTo: columnGuide.topAnchor),
            reviewedStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            reviewedStack.topAnchor.constraint(equalTo: columnGuide.topAnchor),
            reviewedStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: leftStack.trailingAnchor, constant: Layout.topRowMinimumGap),

            decisionsStack.leadingAnchor.constraint(equalTo: columnGuide.leadingAnchor),
            decisionsStack.trailingAnchor.constraint(equalTo: columnGuide.trailingAnchor),
            decisionsStack.bottomAnchor.constraint(equalTo: columnGuide.bottomAnchor),
            decisionsStack.topAnchor.constraint(
                greaterThanOrEqualTo: leftStack.bottomAnchor, constant: Layout.rowsMinimumGap),
            decisionsStack.topAnchor.constraint(
                greaterThanOrEqualTo: reviewedStack.bottomAnchor, constant: Layout.rowsMinimumGap),
            hugWidth
        ]
        if let capsuleWidth = metrics.capsuleWidth {
            constraints.append(capsuleView.widthAnchor.constraint(equalToConstant: capsuleWidth))
        } else {
            constraints.append(
                capsuleView.widthAnchor.constraint(
                    equalTo: capsuleView.heightAnchor, multiplier: Layout.capsuleWidthToHeight))
        }
        if let contentHeight = metrics.contentHeight {
            // The rows set the least height; the capsule only stretches with them
            let height = heightAnchor.constraint(equalToConstant: contentHeight)
            height.priority = UILayoutPriority(999)
            constraints.append(height)
            contentHeightConstraint = height
            // Compact, without that height, the rows pull together
            let hugHeight = heightAnchor.constraint(equalToConstant: 0)
            hugHeight.priority = UILayoutPriority(50)
            constraints.append(hugHeight)
        }
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateDecisionNames()
    }

    /// The names show only while the three items fit the row with them; icon + count otherwise.
    private func updateDecisionNames() {
        let available: CGFloat
        if let maximumContentWidth {
            available = maximumContentWidth - capsuleView.bounds.width - metrics.capsuleToColumn
        } else {
            available = columnGuide.layoutFrame.width
        }
        guard available > 0 else { return }
        let needed = decisionItems.reduce(0) { $0 + $1.widthWithName }
            + metrics.minimumItemSpacing * CGFloat(decisionItems.count - 1)
        let showsNames = needed <= available
        decisionItems.forEach { $0.showsName = showsNames }
    }

    // MARK: - Update

    func update(with state: ProgressOverviewState) {
        guard state != self.state else { return }
        self.state = state

        capsuleView.configure(
            deleted: state.deleted, kept: state.kept, stored: state.stored, total: state.total,
            reviewed: state.reviewed)
        deletedItem.count = state.deleted
        keptItem.count = state.kept
        storedItem.count = state.stored

        if state.isCounted {
            leftLabel.text = state.left.compactFormatted
            percentLabel.text = Strings.percent(state.percent)
            fractionLabel.text = Strings.reviewedFraction(reviewed: state.reviewed, total: state.total)
            accessibilitySummary = Strings.accessibility(state)
        } else {
            // A year before its preload finishes has no total yet
            leftLabel.text = Strings.placeholder
            percentLabel.text = Strings.placeholder
            fractionLabel.text = Strings.placeholderFraction
            accessibilitySummary = nil
        }
        setNeedsLayout()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct ProgressOverviewContentPreview: UIViewRepresentable {
        let style: ProgressOverviewContentView.Style
        let state: ProgressOverviewState

        func makeUIView(context: Context) -> UIView {
            let content = ProgressOverviewContentView(style: style)
            content.update(with: state)

            let container = UIView()
            container.addSubview(content)
            var constraints = [
                content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                content.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                content.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ]
            if style == .display {
                // The host sets the display content's height
                constraints.append(content.heightAnchor.constraint(equalTo: container.heightAnchor))
            }
            NSLayoutConstraint.activate(constraints)
            return container
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Progress overview content") {
        VStack(spacing: 24) {
            ProgressOverviewContentPreview(
                style: .card,
                state: .init(reviewed: 8, total: 92, deleted: 2, kept: 3, stored: 3, isVideo: false))
                .frame(height: 128)
            ProgressOverviewContentPreview(
                style: .card,
                state: .init(reviewed: 12, total: 12, deleted: 4, kept: 8, stored: 0, isVideo: true))
                .frame(height: 128)
            ProgressOverviewContentPreview(
                style: .card,
                state: .init(reviewed: 0, total: 0, deleted: 0, kept: 0, stored: 0, isVideo: false))
                .frame(height: 128)
            ProgressOverviewContentPreview(
                style: .display,
                state: .init(reviewed: 21, total: 29, deleted: 8, kept: 10, stored: 3, isVideo: false))
                .frame(height: 200)
        }
        .padding(20)
        .background(Color(UIColor.cardBackground))
    }
#endif

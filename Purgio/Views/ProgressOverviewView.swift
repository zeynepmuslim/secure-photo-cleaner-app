//
//  ProgressOverviewView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let allCaughtUp = NSLocalizedString("progressOverview.allCaughtUp", comment: "Subtitle once every item of the month is reviewed")
    static func reviewedOfTotal(reviewed: Int, total: Int, isVideo: Bool) -> String {
        let totalText = String.localizedStringWithFormat(
            isVideo
                ? NSLocalizedString("progressOverview.videoCount", comment: "Number of videos, e.g. 29 videos")
                : NSLocalizedString("progressOverview.photoCount", comment: "Number of photos, e.g. 29 photos"),
            total)
        return String(
            format: NSLocalizedString(
                "progressOverview.reviewedOfTotal",
                comment: "Reviewed count out of the total: 1 is the reviewed number, 2 is e.g. '29 photos'"),
            reviewed, totalText)
    }
    static func leftToReview(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("progressOverview.leftToReview", comment: "How many items are still to review"),
            count)
    }
    static func chipAccessibility(_ count: Int, _ action: String) -> String {
        String(
            format: NSLocalizedString(
                "progressOverview.chipAccessibility", comment: "VoiceOver label of a count chip: 1 is the count, 2 the action"),
            count, action)
    }
    static let delete = CommonStrings.delete
    static let keep = NSLocalizedString("progressOverview.keep", comment: "Keep action label")
    static let store = NSLocalizedString("progressOverview.store", comment: "Store action label")
}

/// What the overview shows: the clamped counts of a month or year session.
struct ProgressOverviewState: Equatable {
    let reviewed: Int
    let total: Int
    let deleted: Int
    let kept: Int
    let stored: Int
    let isVideo: Bool

    var left: Int { max(0, total - reviewed) }
    /// The app-wide "complete" test.
    var isComplete: Bool { total > 0 && reviewed >= total }
    /// A year key before its preload finishes has no total yet.
    var isCounted: Bool { total > 0 }
}

/// The month hub's progress card on the iPhone Duo inner display: a `DecisionRingView`, then
/// "21 of 29 photos", "8 left to review" (or "All caught up") and three count chips.
final class ProgressOverviewView: UIView {

    private enum Layout {
        static let innerPadding: CGFloat = 18
        /// The ring's diameter as a share of the card's height, up to `maxRingDiameter`.
        static let ringHeightShare: CGFloat = 0.42
        static let maxRingDiameter: CGFloat = 220
        static let ringToText: CGFloat = 16
        static let titleToSubtitle: CGFloat = 2
        static let textToChips: CGFloat = 14
        static let chipSpacing: CGFloat = 8
        static let chipHeight: CGFloat = 36
        static let chipHorizontalInset: CGFloat = 14
        static let chipIconSpacing: CGFloat = 6
        static let chipIconPointSize: CGFloat = 14
        static let titleFontSize: CGFloat = 18
        static let subtitleFontSize: CGFloat = 14
    }

    private final class CountChip: UIView {
        private let iconView: UIImageView = {
            let imageView = UIImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.setContentHuggingPriority(.required, for: .horizontal)
            return imageView
        }()

        private let countLabel: UILabel = {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
            label.textColor = .textPrimary
            label.setContentCompressionResistancePriority(.required, for: .horizontal)
            return label
        }()

        private let actionTitle: String

        init(systemImage: String, color: UIColor, actionTitle: String) {
            self.actionTitle = actionTitle
            super.init(frame: .zero)
            iconView.image = UIImage(
                systemName: systemImage,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.chipIconPointSize, weight: .bold))
            iconView.tintColor = color
            setupUI()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setupUI() {
            translatesAutoresizingMaskIntoConstraints = false
            // A fill rather than a fixed gray, so it reads on the card in light and dark
            backgroundColor = .tertiarySystemFill
            layer.cornerRadius = Layout.chipHeight / 2
            layer.cornerCurve = .continuous
            isAccessibilityElement = true

            let stack = UIStackView(arrangedSubviews: [iconView, countLabel])
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.axis = .horizontal
            stack.alignment = .center
            stack.spacing = Layout.chipIconSpacing
            addSubview(stack)
            NSLayoutConstraint.activate([
                heightAnchor.constraint(equalToConstant: Layout.chipHeight),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.chipHorizontalInset),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.chipHorizontalInset),
                stack.centerYAnchor.constraint(equalTo: centerYAnchor)
            ])
            setContentHuggingPriority(.required, for: .horizontal)
            setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        /// nil shows "–" (not counted yet).
        func setCount(_ count: Int?) {
            countLabel.text = count.map { $0.compactFormatted } ?? "–"
            accessibilityLabel = count.map { Strings.chipAccessibility($0, actionTitle) } ?? actionTitle
        }
    }

    // MARK: - Views

    private let ringView: DecisionRingView = {
        let ring = DecisionRingView()
        ring.translatesAutoresizingMaskIntoConstraints = false
        return ring
    }()

    private let topGap = UILayoutGuide()
    private let ringToTextGap = UILayoutGuide()
    private let bottomGap = UILayoutGuide()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: Layout.titleFontSize, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedDigitSystemFont(ofSize: Layout.subtitleFontSize, weight: .medium)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    /// Lays the chips out in a row, or one under another when the row doesn't fit, so a count
    /// never truncates.
    private let chipsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = Layout.chipSpacing
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .fill
        return stack
    }()

    private let deletedChip = CountChip(systemImage: "trash", color: ThemeManager.Colors.statusRed, actionTitle: Strings.delete)
    private let keptChip = CountChip(systemImage: "checkmark", color: ThemeManager.Colors.statusGreen, actionTitle: Strings.keep)
    private let storedChip = CountChip(systemImage: "archivebox", color: ThemeManager.Colors.statusYellow, actionTitle: Strings.store)

    private var state: ProgressOverviewState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        [deletedChip, keptChip, storedChip].forEach { chipsStack.addArrangedSubview($0) }

        let chipsRow = UIStackView(arrangedSubviews: [chipsStack])
        chipsRow.axis = .vertical
        chipsRow.alignment = .center

        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(Layout.titleToSubtitle, after: titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(Layout.textToChips, after: subtitleLabel)
        contentStack.addArrangedSubview(chipsRow)
        addSubview(ringView)
        addSubview(contentStack)
        [topGap, ringToTextGap, bottomGap].forEach { addLayoutGuide($0) }

        // The text and chips keep their own heights; the gaps and the ring take the rest
        [titleLabel, subtitleLabel, chipsRow].forEach {
            $0.setContentHuggingPriority(.required, for: .vertical)
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
    }

    private func setupConstraint() {
        let padding = Layout.innerPadding
        // The ring scales with the card (a share of its height), capped so a tall card doesn't
        // blow it up; it gives way first when the card is short or narrow.
        let proportionalDiameter = ringView.heightAnchor.constraint(
            equalTo: heightAnchor, multiplier: Layout.ringHeightShare)
        proportionalDiameter.priority = .defaultHigh
        // The space left over is split evenly: above the ring, between the ring and the text,
        // and below the chips, so the group neither bunches in the middle nor sticks to the edges
        let equalMiddleGap = ringToTextGap.heightAnchor.constraint(equalTo: topGap.heightAnchor)
        equalMiddleGap.priority = .defaultHigh + 1
        let equalBottomGap = bottomGap.heightAnchor.constraint(equalTo: topGap.heightAnchor)
        equalBottomGap.priority = .defaultHigh + 1

        NSLayoutConstraint.activate([
            topGap.topAnchor.constraint(equalTo: topAnchor),
            topGap.bottomAnchor.constraint(equalTo: ringView.topAnchor),
            topGap.heightAnchor.constraint(greaterThanOrEqualToConstant: padding),
            ringToTextGap.topAnchor.constraint(equalTo: ringView.bottomAnchor),
            ringToTextGap.bottomAnchor.constraint(equalTo: contentStack.topAnchor),
            ringToTextGap.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.ringToText),
            bottomGap.topAnchor.constraint(equalTo: contentStack.bottomAnchor),
            bottomGap.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomGap.heightAnchor.constraint(greaterThanOrEqualToConstant: padding),
            equalMiddleGap,
            equalBottomGap,

            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),

            ringView.centerXAnchor.constraint(equalTo: centerXAnchor),
            ringView.heightAnchor.constraint(equalTo: ringView.widthAnchor),
            ringView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -2 * padding),
            ringView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maxRingDiameter),
            proportionalDiameter
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateChipsAxis()
    }

    private func updateChipsAxis() {
        let available = bounds.width - 2 * Layout.innerPadding
        guard available > 0 else { return }
        let chips = [deletedChip, keptChip, storedChip]
        let rowWidth = chips.reduce(0) {
            $0 + $1.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        } + Layout.chipSpacing * CGFloat(chips.count - 1)
        let axis: NSLayoutConstraint.Axis = rowWidth > available ? .vertical : .horizontal
        if chipsStack.axis != axis {
            chipsStack.axis = axis
            // .fill in a row pins the stack to the chips' height, so it never stretches
            chipsStack.alignment = axis == .horizontal ? .fill : .center
        }
    }

    // MARK: - Update

    func update(with state: ProgressOverviewState, animated: Bool = true) {
        guard state != self.state else { return }
        let isFirstUpdate = self.state == nil
        self.state = state

        ringView.configure(
            deleted: state.deleted, kept: state.kept, stored: state.stored, total: state.total,
            reviewed: state.reviewed, animated: animated && !isFirstUpdate)

        if state.isCounted {
            titleLabel.text = Strings.reviewedOfTotal(reviewed: state.reviewed, total: state.total, isVideo: state.isVideo)
            subtitleLabel.text = state.isComplete ? Strings.allCaughtUp : Strings.leftToReview(state.left)
            subtitleLabel.isHidden = false
            deletedChip.setCount(state.deleted)
            keptChip.setCount(state.kept)
            storedChip.setCount(state.stored)
        } else {
            titleLabel.text = "–"
            subtitleLabel.isHidden = true
            [deletedChip, keptChip, storedChip].forEach { $0.setCount(nil) }
        }
        setNeedsLayout()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct ProgressOverviewPreview: UIViewRepresentable {
        let state: ProgressOverviewState

        func makeUIView(context: Context) -> ProgressOverviewView {
            let view = ProgressOverviewView()
            view.update(with: state, animated: false)
            return view
        }

        func updateUIView(_ uiView: ProgressOverviewView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Progress overview") {
        HStack(spacing: 20) {
            ProgressOverviewPreview(
                state: .init(reviewed: 21, total: 29, deleted: 5, kept: 13, stored: 3, isVideo: false))
            ProgressOverviewPreview(
                state: .init(reviewed: 12, total: 12, deleted: 4, kept: 8, stored: 0, isVideo: true))
        }
        .frame(height: 480)
        .padding(20)
        .background(Color(UIColor.mainBackground))
    }
#endif

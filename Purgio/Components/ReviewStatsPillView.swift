//
//  ReviewStatsPillView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 08.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static func accessibilitySummary(_ counts: ReviewStatsPillView.Counts) -> String {
        String(
            format: NSLocalizedString(
                "monthReview.statsAccessibility",
                comment: "VoiceOver summary of the review stats: reviewed, total, deleted, kept, stored"),
            counts.reviewed, counts.total, counts.deleted, counts.kept, counts.stored)
    }
}

/// A white capsule above the card in MonthReview's sideways layout (iPhone Duo inner display):
/// "reviewed / total", a one-color progress bar, then the deleted, kept and stored counts.
final class ReviewStatsPillView: UIView {

    struct Counts: Equatable {
        let reviewed: Int
        let total: Int
        let deleted: Int
        let kept: Int
        let stored: Int
    }

    private enum Layout {
        static let height: CGFloat = 36
        static let barWidth: CGFloat = 96
        static let barHeight: CGFloat = 6
        static let horizontalInset: CGFloat = 14
        static let groupSpacing: CGFloat = 12
        static let itemSpacing: CGFloat = 10
        static let iconSpacing: CGFloat = 4
        static let iconPointSize: CGFloat = 12
    }

    static var height: CGFloat { Layout.height }

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Layout.groupSpacing
        return stack
    }()

    private let progressLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    /// Track filled from the leading edge by the reviewed share of the total.
    private let progressTrack: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemGray5
        view.layer.cornerRadius = Layout.barHeight / 2
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        return view
    }()

    private let progressFill: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // Black in light mode, white in dark, so it reads on the card either way
        view.backgroundColor = .label
        return view
    }()
    private var fillWidthConstraint: NSLayoutConstraint?

    private let divider: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        return view
    }()

    private let countsStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Layout.itemSpacing
        return stack
    }()

    private let deletedLabel = UILabel()
    private let keptLabel = UILabel()
    private let storedLabel = UILabel()

    private var counts: Counts?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = Layout.height / 2
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 10

        isAccessibilityElement = true
        accessibilityTraits = .staticText

        addSubview(contentStack)
        contentStack.addArrangedSubview(progressLabel)
        contentStack.addArrangedSubview(progressTrack)
        progressTrack.addSubview(progressFill)
        contentStack.addArrangedSubview(divider)
        contentStack.addArrangedSubview(countsStack)

        countsStack.addArrangedSubview(
            makeCountItem(label: deletedLabel, systemImage: "trash.fill", color: ThemeManager.Colors.statusRed))
        countsStack.addArrangedSubview(
            makeCountItem(label: keptLabel, systemImage: "checkmark.circle.fill", color: ThemeManager.Colors.statusGreen))
        countsStack.addArrangedSubview(
            makeCountItem(label: storedLabel, systemImage: "archivebox.fill", color: ThemeManager.Colors.statusYellow))
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Layout.height),

            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalInset),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalInset),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            progressTrack.widthAnchor.constraint(equalToConstant: Layout.barWidth),
            progressTrack.heightAnchor.constraint(equalToConstant: Layout.barHeight),

            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 16)
        ])

        let fillWidth = progressFill.widthAnchor.constraint(equalToConstant: 0)
        fillWidthConstraint = fillWidth
        NSLayoutConstraint.activate([
            fillWidth,
            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor)
        ])
    }

    private func makeCountItem(label: UILabel, systemImage: String, color: UIColor) -> UIView {
        let icon = UIImageView(image: UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Layout.iconPointSize, weight: .semibold)))
        icon.tintColor = color
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)

        label.font = .monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = .label
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        let item = UIStackView(arrangedSubviews: [icon, label])
        item.axis = .horizontal
        item.alignment = .center
        item.spacing = Layout.iconSpacing
        return item
    }

    // MARK: - Update

    func update(with counts: Counts, animated: Bool = true) {
        guard counts != self.counts else { return }
        let isFirstUpdate = self.counts == nil
        self.counts = counts

        let reviewedText = NSMutableAttributedString(
            string: counts.reviewed.compactFormatted,
            attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold), .foregroundColor: UIColor.label])
        reviewedText.append(NSAttributedString(
            string: " / \(counts.total.compactFormatted)",
            attributes: [
                .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.secondaryLabel
            ]))
        progressLabel.attributedText = reviewedText

        deletedLabel.text = counts.deleted.compactFormatted
        keptLabel.text = counts.kept.compactFormatted
        storedLabel.text = counts.stored.compactFormatted

        let share = min(1, CGFloat(max(counts.reviewed, 0)) / CGFloat(max(counts.total, 1)))
        fillWidthConstraint?.constant = (Layout.barWidth * share).rounded()
        if animated && !isFirstUpdate && window != nil {
            UIView.animate(withDuration: 0.3) { self.layoutIfNeeded() }
        }

        accessibilityLabel = Strings.accessibilitySummary(counts)
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct ReviewStatsPillPreview: UIViewRepresentable {
        func makeUIView(context: Context) -> ReviewStatsPillView {
            let pill = ReviewStatsPillView()
            pill.update(with: .init(reviewed: 14, total: 42, deleted: 6, kept: 5, stored: 3), animated: false)
            return pill
        }

        func updateUIView(_ uiView: ReviewStatsPillView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Stats pill") {
        ReviewStatsPillPreview()
            .fixedSize()
            .padding(40)
            .background(Color(UIColor.secondarySystemBackground))
    }
#endif

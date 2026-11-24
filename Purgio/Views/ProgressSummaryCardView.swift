//
//  ProgressSummaryCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

/// The month hub's overview card in one column (phones, the Duo's cover display, Split View,
/// the months list's detail pane): a split review capsule and, beside it, the number left and
/// the percent reviewed over the delete / keep / store counts (`ProgressOverviewContentView`).
final class ProgressSummaryCardView: UIView {

    private enum Layout {
        /// Cards' inner padding
        static let innerPadding: CGFloat = 18
        static let compactInnerPadding: CGFloat = 12
    }

    private let contentView = ProgressOverviewContentView(style: .card)
    private var paddingConstraints: [NSLayoutConstraint] = []

    /// The card's height at its regular size, for a screen deciding whether it has the room
    static let regularHeight: CGFloat = ProgressOverviewContentView.cardContentHeight + 2 * Layout.innerPadding

    /// A short column (iPhone SE): tighter padding and a content only as tall as its rows
    var isCompact = false {
        didSet {
            guard isCompact != oldValue else { return }
            contentView.isCompact = isCompact
            let padding = isCompact ? Layout.compactInnerPadding : Layout.innerPadding
            // Leading and top are positive, trailing and bottom negative
            paddingConstraints.forEach { $0.constant = $0.constant < 0 ? -padding : padding }
        }
    }

    // MARK: - Init

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
        isAccessibilityElement = true

        addSubview(contentView)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    private func setupConstraint() {
        let padding = Layout.innerPadding
        paddingConstraints = [
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            contentView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding)
        ]
        NSLayoutConstraint.activate(paddingConstraints)
    }

    // MARK: - Update

    func update(with state: ProgressOverviewState) {
        contentView.update(with: state)
        accessibilityLabel = contentView.accessibilitySummary
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct ProgressSummaryCardPreview: UIViewRepresentable {
        let state: ProgressOverviewState

        func makeUIView(context: Context) -> ProgressSummaryCardView {
            let view = ProgressSummaryCardView()
            view.update(with: state)
            return view
        }

        func updateUIView(_ uiView: ProgressSummaryCardView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Progress summary card") {
        VStack(spacing: 10) {
            ProgressSummaryCardPreview(
                state: .init(reviewed: 8, total: 92, deleted: 2, kept: 3, stored: 3, isVideo: false))
            ProgressSummaryCardPreview(
                state: .init(reviewed: 0, total: 92, deleted: 0, kept: 0, stored: 0, isVideo: false))
            ProgressSummaryCardPreview(
                state: .init(reviewed: 12, total: 12, deleted: 4, kept: 8, stored: 0, isVideo: true))
            ProgressSummaryCardPreview(
                state: .init(reviewed: 0, total: 0, deleted: 0, kept: 0, stored: 0, isVideo: false))
        }
        .frame(height: 690)
        .padding(20)
        .background(Color(UIColor.mainBackground))
    }
#endif

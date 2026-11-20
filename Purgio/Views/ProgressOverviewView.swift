//
//  ProgressOverviewView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// What the overview shows: the clamped counts of a month or year session.
struct ProgressOverviewState: Equatable {
    let reviewed: Int
    let total: Int
    let deleted: Int
    let kept: Int
    let stored: Int
    let isVideo: Bool

    var left: Int { max(0, total - reviewed) }
    /// The reviewed share, rounded: 0 while there's no total.
    var percent: Int { reviewed.roundedPercent(of: total) }
    /// The app-wide "complete" test.
    var isComplete: Bool { total > 0 && reviewed >= total }
    /// A year key before its preload finishes has no total yet.
    var isCounted: Bool { total > 0 }
}

/// The month hub's progress card on the iPhone Duo inner display: the one-column card's content
/// (`ProgressOverviewContentView`) scaled up, with a big split capsule, and centered in the card.
final class ProgressOverviewView: UIView {

    private enum Layout {
        static let innerPadding: CGFloat = 18
        /// The capsule's height as a share of the card's height, up to `maxCapsuleHeight`.
        static let capsuleHeightShare: CGFloat = 0.42
        static let maxCapsuleHeight: CGFloat = 220
    }

    private let contentView = ProgressOverviewContentView(style: .display)

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
    }

    private func setupConstraint() {
        let padding = Layout.innerPadding
        // The content is as tall as its capsule, which scales with the card (a share of its
        // height), capped so a tall card doesn't blow it up; in a short card the rows set it.
        let proportionalHeight = contentView.heightAnchor.constraint(
            equalTo: heightAnchor, multiplier: Layout.capsuleHeightShare)
        proportionalHeight.priority = .defaultHigh
        let maximumHeight = contentView.heightAnchor.constraint(lessThanOrEqualToConstant: Layout.maxCapsuleHeight)
        maximumHeight.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: padding),
            contentView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -padding),
            contentView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: padding),
            contentView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -padding),
            proportionalHeight,
            maximumHeight
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // The content hugs its rows, so the card tells it how wide it may get
        contentView.maximumContentWidth = max(0, bounds.width - 2 * Layout.innerPadding)
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
    private struct ProgressOverviewPreview: UIViewRepresentable {
        let state: ProgressOverviewState

        func makeUIView(context: Context) -> ProgressOverviewView {
            let view = ProgressOverviewView()
            view.update(with: state)
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

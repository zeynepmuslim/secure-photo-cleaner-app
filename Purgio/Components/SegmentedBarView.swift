//
//  SegmentedBarView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 1.02.2026.
//

import UIKit

final class SegmentedBarView: UIView {

    struct Segment {
        let color: UIColor
        let percentage: CGFloat   // 0.0 to 1.0

        init(color: UIColor, percentage: CGFloat) {
            self.color = color
            self.percentage = max(0, min(1, percentage))   // 0 to 1
        }
    }

    private let backgroundBar: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var segmentViews: [UIView] = []
    private var separatorViews: [UIView] = []
    private var segmentWidthConstraints: [NSLayoutConstraint] = []
    private var currentSegments: [Segment] = []
    private var lastKnownWidth: CGFloat = 0

    var cornerRadius: CGFloat = 4 {
        didSet {
            backgroundBar.layer.cornerRadius = cornerRadius
            updateCornerRadius()
        }
    }

    var separatorWidth: CGFloat = 2 {
        didSet {
            separatorViews.forEach { separator in
                separator.constraints.forEach { constraint in
                    if constraint.firstAttribute == .width {
                        constraint.constant = separatorWidth
                    }
                }
            }
        }
    }

    var separatorColor: UIColor = .cardBackground {
        didSet {
            separatorViews.forEach { $0.backgroundColor = separatorColor }
        }
    }

    var barBackgroundColor: UIColor = .systemGray5 {
        didSet {
            backgroundBar.backgroundColor = barBackgroundColor
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundBar.layer.cornerRadius = cornerRadius
        addSubview(backgroundBar)
        setupConstraint()
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            backgroundBar.topAnchor.constraint(equalTo: topAnchor),
            backgroundBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBar.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func configure(segments: [Segment], animated: Bool = true) {
        segmentViews.forEach { $0.removeFromSuperview() }
        separatorViews.forEach { $0.removeFromSuperview() }
        segmentViews.removeAll()
        separatorViews.removeAll()
        segmentWidthConstraints.removeAll()

        guard !segments.isEmpty else {
            currentSegments = []
            return
        }

        // Normalize percentages to ensure sum is 1.0
        let totalPercentage = segments.reduce(0) { $0 + $1.percentage }
        let normalizedSegments = segments.map { segment -> Segment in
            let normalizedPercentage = totalPercentage > 0 ? segment.percentage / totalPercentage : 0
            return Segment(color: segment.color, percentage: normalizedPercentage)
        }

        currentSegments = normalizedSegments

        var previousSegment: UIView?
        for segment in normalizedSegments {
            let segmentView = UIView()
            segmentView.backgroundColor = segment.color
            segmentView.translatesAutoresizingMaskIntoConstraints = false
            backgroundBar.addSubview(segmentView)
            segmentViews.append(segmentView)

            NSLayoutConstraint.activate([
                segmentView.topAnchor.constraint(equalTo: backgroundBar.topAnchor),
                segmentView.bottomAnchor.constraint(equalTo: backgroundBar.bottomAnchor)
            ])

            if let previous = previousSegment {
                segmentView.leadingAnchor.constraint(equalTo: previous.trailingAnchor).isActive = true
            } else {
                segmentView.leadingAnchor.constraint(equalTo: backgroundBar.leadingAnchor).isActive = true
            }

            let widthConstraint = segmentView.widthAnchor.constraint(equalToConstant: 0)
            widthConstraint.isActive = true
            segmentWidthConstraints.append(widthConstraint)

            previousSegment = segmentView
        }

        for index in 0 ..< segmentViews.count - 1 {
            let separator = UIView()
            separator.backgroundColor = separatorColor
            separator.translatesAutoresizingMaskIntoConstraints = false
            backgroundBar.addSubview(separator)
            backgroundBar.bringSubviewToFront(separator)
            separatorViews.append(separator)

            let currentSegment = segmentViews[index]
            NSLayoutConstraint.activate([
                separator.topAnchor.constraint(equalTo: backgroundBar.topAnchor),
                separator.leadingAnchor.constraint(equalTo: currentSegment.trailingAnchor),
                separator.bottomAnchor.constraint(equalTo: backgroundBar.bottomAnchor),
                separator.widthAnchor.constraint(equalToConstant: separatorWidth)
            ])
        }

        setNeedsLayout()
        layoutIfNeeded()
        updateSegmentWidths(normalizedSegments, animated: animated)
        updateCornerRadius()
    }

    private func updateSegmentWidths(_ segments: [Segment], animated: Bool) {
        let barWidth = bounds.width

        guard barWidth > 0, !segments.isEmpty else {
            // Width will be set in layoutSubviews when view gets its bounds
            return
        }

        guard segmentWidthConstraints.count == segments.count else { return }

        lastKnownWidth = barWidth

        for (index, segment) in segments.enumerated() {
            segmentWidthConstraints[index].constant = barWidth * segment.percentage
        }

        if animated {
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                self.layoutIfNeeded()
                self.updateCornerRadius()
            }
        } else {
            layoutIfNeeded()
            updateCornerRadius()
        }
    }

    private func updateCornerRadius() {
        segmentViews.forEach { segment in
            segment.layer.maskedCorners = []
            segment.layer.cornerRadius = cornerRadius
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let currentWidth = bounds.width
        if currentWidth > 0 && currentWidth != lastKnownWidth && !currentSegments.isEmpty {
            lastKnownWidth = currentWidth
            updateSegmentWidths(currentSegments, animated: false)
        }

        updateCornerRadius()
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct SegmentedBarViewPreview: UIViewRepresentable {
        let configure: (SegmentedBarView) -> Void

        func makeUIView(context: Context) -> SegmentedBarView {
            let view = SegmentedBarView()
            configure(view)
            return view
        }

        func updateUIView(_ uiView: SegmentedBarView, context: Context) {
            configure(uiView)
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: SegmentedBarView, context: Context) -> CGSize? {
            return CGSize(width: proposal.width ?? 360, height: 14)
        }
    }

    @available(iOS 17.0, *)
    #Preview("Three Segments", traits: .sizeThatFitsLayout) {
        SegmentedBarViewPreview { view in
            view.configure(
                segments: [
                    .init(color: .systemRed, percentage: 0.5),
                    .init(color: .systemOrange, percentage: 0.3),
                    .init(color: .systemGray3, percentage: 0.2)
                ], animated: false)
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Two Segments", traits: .sizeThatFitsLayout) {
        SegmentedBarViewPreview { view in
            view.configure(
                segments: [
                    .init(color: .systemBlue, percentage: 0.7),
                    .init(color: .systemGray4, percentage: 0.3)
                ], animated: false)
        }
        .padding()
    }
#endif

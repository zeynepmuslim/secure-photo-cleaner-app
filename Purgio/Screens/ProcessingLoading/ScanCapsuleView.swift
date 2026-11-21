//
//  ScanCapsuleView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.11.2026.
//

import UIKit

/// The filter loading screen's capsule: it fills from the bottom while a filter checks a month.
/// Finds (blue) sit at the bottom, the other checked items (ink) above them, and what's left
/// is a gray track. Before the first result it is a dashed outline (not started).
/// It follows `ReviewCapsuleView`'s rules: radius width / 2, gaps of about width / 12 and a
/// non-zero segment at least 3pt tall. No red or yellow: nothing is decided here.
final class ScanCapsuleView: UIView {

    private enum Layout {
        static let size = CGSize(width: 60, height: 250)
        /// `ReviewCapsuleView`'s standard width, which its gap, outline and dashes are tuned for
        static let referenceWidth: CGFloat = 12
        static let minimumGap: CGFloat = 1
        static let minimumSegmentHeight: CGFloat = 3
        static let outlineWidth: CGFloat = 1.5
        static let outlineDashPattern: [CGFloat] = [3, 2.5]
        /// The outline stops growing at this scale, so a large capsule's dashes stay fine
        static let maximumOutlineScale: CGFloat = 2
        static let fillDuration: TimeInterval = 0.25
    }

    /// Bottom-up: found, checked (without the finds), left
    private var segmentValues: [CGFloat] = [0, 0, 0]
    private var isStarted = false
    /// The fill's first frames are set directly, so it doesn't grow in from a zero rect
    private var hasLaidOutSegments = false

    private let segmentsContainerView: UIView = {
        let view = UIView()
        view.clipsToBounds = true
        view.layer.cornerCurve = .continuous
        view.isUserInteractionEnabled = false
        return view
    }()

    private let foundView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        return view
    }()

    private let checkedView: UIView = {
        let view = UIView()
        view.backgroundColor = .label
        return view
    }()

    private let leftView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        return view
    }()

    private let outlineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = Layout.outlineWidth
        return layer
    }()

    private var segmentViews: [UIView] { [foundView, checkedView, leftView] }

    private var segmentGap: CGFloat {
        max(Layout.minimumGap, (bounds.width / Layout.referenceWidth).rounded())
    }

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize { Layout.size }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        isAccessibilityElement = false
        isUserInteractionEnabled = false

        addSubview(segmentsContainerView)
        segmentViews.forEach { segmentsContainerView.addSubview($0) }
        layer.addSublayer(outlineLayer)

        applyOutlineColor()
        applyMode()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ScanCapsuleView, _: UITraitCollection) in
                self.applyOutlineColor()
            }
        }
    }

    // MARK: - Configure

    /// `found` is part of `checked`. Nothing checked yet (or no total) shows the dashed outline.
    /// The fill animates unless Reduce Motion is on.
    func configure(checked: Int, found: Int, total: Int, animated: Bool) {
        let checkedValue = max(0, min(checked, total))
        let foundValue = max(0, min(found, checkedValue))
        isStarted = total > 0 && checkedValue > 0
        segmentValues = isStarted
            ? [CGFloat(foundValue), CGFloat(checkedValue - foundValue), CGFloat(total - checkedValue)]
            : [0, 0, 0]
        applyMode()

        guard bounds.width > 0, bounds.height > 0 else {
            setNeedsLayout()
            return
        }
        let canAnimate = animated && hasLaidOutSegments && window != nil
            && !UIAccessibility.isReduceMotionEnabled
        if canAnimate {
            UIView.animate(
                withDuration: Layout.fillDuration, delay: 0,
                options: [.curveEaseOut, .beginFromCurrentState, .allowUserInteraction]
            ) {
                self.layoutSegments()
            }
        } else {
            UIView.performWithoutAnimation { layoutSegments() }
        }
    }

    private func applyMode() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        segmentsContainerView.isHidden = !isStarted
        outlineLayer.isHidden = isStarted
        CATransaction.commit()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let sizeChanged = segmentsContainerView.frame != bounds
        segmentsContainerView.frame = bounds
        segmentsContainerView.layer.cornerRadius = bounds.width / 2
        if sizeChanged || !hasLaidOutSegments {
            UIView.performWithoutAnimation { layoutSegments() }
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let outlineScale = min(bounds.width / Layout.referenceWidth, Layout.maximumOutlineScale)
        let outlineWidth = Layout.outlineWidth * outlineScale
        let outlineRect = bounds.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2)
        outlineLayer.frame = bounds
        outlineLayer.lineWidth = outlineWidth
        outlineLayer.lineDashPattern = Layout.outlineDashPattern.map { NSNumber(value: Double($0 * outlineScale)) }
        outlineLayer.path = UIBezierPath(roundedRect: outlineRect, cornerRadius: outlineRect.width / 2).cgPath
        CATransaction.commit()
    }

    /// A segment with nothing in it keeps its place at zero height, so it grows from where it
    /// will sit instead of from the capsule's top.
    private func layoutSegments() {
        guard bounds.width > 0, bounds.height > 0 else { return }
        hasLaidOutSegments = true
        let heights = segmentHeights(barHeight: bounds.height)
        var bottom = bounds.height
        for (index, segment) in segmentViews.enumerated() {
            let height = heights[index]
            segment.frame = CGRect(x: 0, y: bottom - height, width: bounds.width, height: height)
            if height > 0 { bottom -= height + segmentGap }
        }
    }

    /// Proportional heights with every non-zero segment raised to the minimum; the extra comes
    /// from the largest segment, so the segments and their gaps still add up to `barHeight`.
    private func segmentHeights(barHeight: CGFloat) -> [CGFloat] {
        let sum = segmentValues.reduce(0, +)
        let visibleCount = segmentValues.filter { $0 > 0 }.count
        guard sum > 0, visibleCount > 0 else { return segmentValues.map { _ in 0 } }

        let available = max(0, barHeight - segmentGap * CGFloat(visibleCount - 1))
        var heights = segmentValues.map { available * $0 / sum }
        guard let largestIndex = heights.indices.max(by: { heights[$0] < heights[$1] }) else { return heights }

        var deficit: CGFloat = 0
        for index in heights.indices where index != largestIndex {
            if segmentValues[index] > 0 && heights[index] < Layout.minimumSegmentHeight {
                deficit += Layout.minimumSegmentHeight - heights[index]
                heights[index] = Layout.minimumSegmentHeight
            }
        }
        heights[largestIndex] = max(0, heights[largestIndex] - deficit)
        return heights
    }

    // MARK: - Colors

    /// The fills are views with dynamic colors; only the outline's CGColor needs refreshing.
    private func applyOutlineColor() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        outlineLayer.strokeColor = UIColor.systemGray3.resolvedColor(with: traitCollection).cgColor
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyOutlineColor()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

private struct ScanCapsulePreview: UIViewRepresentable {
    let checked: Int
    let found: Int
    let total: Int

    func makeUIView(context: Context) -> ScanCapsuleView {
        let view = ScanCapsuleView()
        view.configure(checked: checked, found: found, total: total, animated: false)
        return view
    }

    func updateUIView(_ uiView: ScanCapsuleView, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Scan capsule states") {
    HStack(spacing: 32) {
        ScanCapsulePreview(checked: 0, found: 0, total: 57)
        ScanCapsulePreview(checked: 23, found: 3, total: 57)
        ScanCapsulePreview(checked: 23, found: 0, total: 57)
        ScanCapsulePreview(checked: 57, found: 5, total: 57)
    }
    .frame(width: 330, height: 250)
    .padding(24)
}
#endif

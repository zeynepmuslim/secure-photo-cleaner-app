//
//  ReviewCapsuleView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 16.11.2026.
//

import UIKit

/// A small vertical capsule that shows a month's review state: a dashed outline before it is
/// started, a bottom-up fill split by choice (delete, keep, store, then what's left) while in
/// progress, and a green capsule stamped with a check once everything is reviewed.
final class ReviewCapsuleView: UIView {

    private enum Layout {
        static let size = CGSize(width: 12, height: 40)
        static let segmentGap: CGFloat = 1
        static let minimumSegmentHeight: CGFloat = 3
        static let outlineWidth: CGFloat = 1.5
        static let outlineDashPattern: [NSNumber] = [3, 2.5]
        /// The finished capsule is this much narrower than the slot
        static let finishedWidthInset: CGFloat = 2
        static let checkBoxSize: CGFloat = 22
        /// The check is drawn in a 24-unit box: "M5 12.5 l4.5 4.5 L19 7"
        static let checkUnitBox: CGFloat = 24
        static let checkOutlineStroke: CGFloat = 7.5
        static let checkCoreStroke: CGFloat = 3.6
        static let checkRotation: CGFloat = -8 * .pi / 180
    }

    private enum Mode {
        case empty
        case notStarted
        case inProgress
        case finished
    }

    private var mode: Mode = .empty
    /// Bottom-up: deleted, kept, stored, left
    private var segmentValues: [CGFloat] = [0, 0, 0, 0]

    private let segmentsContainerLayer: CALayer = {
        let layer = CALayer()
        layer.masksToBounds = true
        layer.cornerCurve = .continuous
        return layer
    }()

    private let deletedLayer = CALayer()
    private let keptLayer = CALayer()
    private let storedLayer = CALayer()
    private let leftLayer = CALayer()

    private let outlineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = Layout.outlineWidth
        layer.lineDashPattern = Layout.outlineDashPattern
        return layer
    }()

    private let finishedCapsuleLayer: CALayer = {
        let layer = CALayer()
        layer.cornerCurve = .continuous
        return layer
    }()

    private let checkContainerLayer = CALayer()
    private let checkOutlineLayer = ReviewCapsuleView.makeCheckLayer(stroke: Layout.checkOutlineStroke)
    private let checkCoreLayer = ReviewCapsuleView.makeCheckLayer(stroke: Layout.checkCoreStroke)

    private var segmentLayers: [CALayer] { [deletedLayer, keptLayer, storedLayer, leftLayer] }

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
        // The finished check is wider than the capsule
        clipsToBounds = false
        isAccessibilityElement = false
        isUserInteractionEnabled = false

        layer.addSublayer(segmentsContainerLayer)
        segmentLayers.forEach { segmentsContainerLayer.addSublayer($0) }
        layer.addSublayer(outlineLayer)
        layer.addSublayer(finishedCapsuleLayer)
        layer.addSublayer(checkContainerLayer)
        checkContainerLayer.addSublayer(checkOutlineLayer)
        checkContainerLayer.addSublayer(checkCoreLayer)
        checkContainerLayer.setAffineTransform(CGAffineTransform(rotationAngle: Layout.checkRotation))

        applyColors()
        applyMode()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ReviewCapsuleView, _: UITraitCollection) in
                self.applyColors()
            }
        }
    }

    private static func makeCheckLayer(stroke: CGFloat) -> CAShapeLayer {
        let scale = Layout.checkBoxSize / Layout.checkUnitBox
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 12.5))
        path.addLine(to: CGPoint(x: 9.5, y: 17))
        path.addLine(to: CGPoint(x: 19, y: 7))
        path.apply(CGAffineTransform(scaleX: scale, y: scale))

        let layer = CAShapeLayer()
        layer.path = path.cgPath
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = stroke * scale
        layer.lineCap = .round
        layer.lineJoin = .round
        layer.frame = CGRect(x: 0, y: 0, width: Layout.checkBoxSize, height: Layout.checkBoxSize)
        return layer
    }

    // MARK: - Configure

    /// `total` is the month's total; the capsule is finished when `total > 0 && reviewed >= total`
    /// and not started while `reviewed` is 0. The three counts are scaled down when they add up to
    /// more than `reviewed`.
    func configure(deleted: Int, kept: Int, stored: Int, total: Int, reviewed: Int) {
        if total > 0 && reviewed >= total {
            mode = .finished
        } else if reviewed <= 0 {
            mode = .notStarted
        } else {
            mode = .inProgress
            var counts = [CGFloat(max(0, deleted)), CGFloat(max(0, kept)), CGFloat(max(0, stored))]
            let decided = counts.reduce(0, +)
            let reviewedValue = CGFloat(reviewed)
            if decided > reviewedValue, decided > 0 {
                counts = counts.map { $0 * reviewedValue / decided }
            }
            // With no total yet, what's reviewed is all there is to show
            let left = max(0, CGFloat(total) - reviewedValue)
            segmentValues = counts + [left]
        }
        applyMode()
        setNeedsLayout()
    }

    /// Back to nothing drawn, for cell reuse
    func reset() {
        mode = .empty
        segmentValues = [0, 0, 0, 0]
        applyMode()
        setNeedsLayout()
    }

    private func applyMode() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        segmentsContainerLayer.isHidden = mode != .inProgress
        outlineLayer.isHidden = mode != .notStarted
        finishedCapsuleLayer.isHidden = mode != .finished
        checkContainerLayer.isHidden = mode != .finished
        CATransaction.commit()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        segmentsContainerLayer.frame = bounds
        segmentsContainerLayer.cornerRadius = bounds.width / 2
        layoutSegments()

        let outlineRect = bounds.insetBy(dx: Layout.outlineWidth / 2, dy: Layout.outlineWidth / 2)
        outlineLayer.frame = bounds
        outlineLayer.path = UIBezierPath(roundedRect: outlineRect, cornerRadius: outlineRect.width / 2).cgPath

        let finishedWidth = max(0, bounds.width - Layout.finishedWidthInset)
        finishedCapsuleLayer.frame = CGRect(
            x: (bounds.width - finishedWidth) / 2, y: 0, width: finishedWidth, height: bounds.height)
        finishedCapsuleLayer.cornerRadius = finishedWidth / 2

        // Bounds and position, not frame: the layer is rotated
        checkContainerLayer.bounds = CGRect(x: 0, y: 0, width: Layout.checkBoxSize, height: Layout.checkBoxSize)
        checkContainerLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)

        CATransaction.commit()
    }

    private func layoutSegments() {
        let heights = segmentHeights(barHeight: bounds.height)
        var bottom = bounds.height
        for (index, segment) in segmentLayers.enumerated() {
            let height = heights[index]
            segment.isHidden = height <= 0
            guard height > 0 else { continue }
            segment.frame = CGRect(x: 0, y: bottom - height, width: bounds.width, height: height)
            bottom -= height + Layout.segmentGap
        }
    }

    /// Proportional heights with every non-zero segment raised to the minimum; the extra comes
    /// from the largest segment, so the segments and their gaps still add up to `barHeight`.
    private func segmentHeights(barHeight: CGFloat) -> [CGFloat] {
        let sum = segmentValues.reduce(0, +)
        let visibleCount = segmentValues.filter { $0 > 0 }.count
        guard sum > 0, visibleCount > 0 else { return segmentValues.map { _ in 0 } }

        let available = max(0, barHeight - Layout.segmentGap * CGFloat(visibleCount - 1))
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

    private func applyColors() {
        let green = ThemeManager.Colors.statusGreen.resolvedColor(with: traitCollection).cgColor

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        deletedLayer.backgroundColor = ThemeManager.Colors.statusRed.resolvedColor(with: traitCollection).cgColor
        keptLayer.backgroundColor = green
        storedLayer.backgroundColor = ThemeManager.Colors.statusYellow.resolvedColor(with: traitCollection).cgColor
        leftLayer.backgroundColor = UIColor.systemGray5.resolvedColor(with: traitCollection).cgColor
        outlineLayer.strokeColor = UIColor.systemGray3.resolvedColor(with: traitCollection).cgColor
        finishedCapsuleLayer.backgroundColor = green
        checkOutlineLayer.strokeColor = green
        checkCoreLayer.strokeColor = UIColor.white.cgColor
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyColors()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

private struct ReviewCapsulePreview: UIViewRepresentable {
    let deleted: Int
    let kept: Int
    let stored: Int
    let total: Int
    let reviewed: Int

    func makeUIView(context: Context) -> ReviewCapsuleView {
        let view = ReviewCapsuleView()
        view.configure(deleted: deleted, kept: kept, stored: stored, total: total, reviewed: reviewed)
        return view
    }

    func updateUIView(_ uiView: ReviewCapsuleView, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Review capsule states") {
    HStack(spacing: 24) {
        ReviewCapsulePreview(deleted: 0, kept: 0, stored: 0, total: 29, reviewed: 0)
        ReviewCapsulePreview(deleted: 8, kept: 10, stored: 3, total: 29, reviewed: 21)
        ReviewCapsulePreview(deleted: 1, kept: 0, stored: 0, total: 2000, reviewed: 1)
        ReviewCapsulePreview(deleted: 20, kept: 9, stored: 0, total: 29, reviewed: 29)
    }
    .frame(height: 40)
    .padding(24)
}
#endif

//
//  ReviewCapsuleView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 16.11.2026.
//

import UIKit

/// A vertical capsule that shows a month's review state: a dashed outline before it is
/// started, a bottom-up fill split by choice (delete, keep, store, then what's left) while in
/// progress, and the stamp (`ReviewStampView`) once everything is reviewed.
/// 12×40 by default; at any other size the gaps, the outline and the check scale with its width.
final class ReviewCapsuleView: UIView {

    private enum Layout {
        static let size = CGSize(width: 12, height: 40)
        /// The outline stops growing at this scale, so a large capsule's dashes stay fine
        static let maximumOutlineScale: CGFloat = 2
        static let segmentGap: CGFloat = 1
        static let minimumSegmentHeight: CGFloat = 3
        static let outlineWidth: CGFloat = 1.5
        static let outlineDashPattern: [NSNumber] = [3, 2.5]
        /// The finished capsule is this much narrower than the slot
        static let finishedWidthInset: CGFloat = 2
    }

    private enum Mode {
        case empty
        case notStarted
        case inProgress
        case finished
    }

    private var mode: Mode = .empty

    /// true: with a total, the capsule always shows the split fill, all gray before it's started
    /// and the full delete / keep / store split once finished (no stamp); the dashed outline
    /// only while there's no total. Set it before `configure`.
    var alwaysShowsSplit = false

    /// true: in progress, the fill is one ink segment for everything reviewed over what's left,
    /// instead of the delete / keep / store split. Set it before `configure`.
    var usesSingleProgressColor = false {
        didSet { if usesSingleProgressColor != oldValue { applyColors() } }
    }
    /// The finished stamp's check border (`ReviewStampView.checkBorderColor`); nil is its default
    var stampCheckBorderColor: UIColor? {
        get { stampView.checkBorderColor }
        set { stampView.checkBorderColor = newValue }
    }

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

    /// The finished state: the shared stamp, sized to this capsule in `layoutSubviews`
    private let stampView = ReviewStampView()

    private var segmentLayers: [CALayer] { [deletedLayer, keptLayer, storedLayer, leftLayer] }

    /// How much larger than the standard 12pt-wide capsule this one is
    private var sizeScale: CGFloat { bounds.width / Layout.size.width }
    private var segmentGap: CGFloat { max(Layout.segmentGap, (Layout.segmentGap * sizeScale).rounded()) }

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
        addSubview(stampView)

        applyColors()
        applyMode()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ReviewCapsuleView, _: UITraitCollection) in
                self.applyColors()
            }
        }
    }

    // MARK: - Configure

    /// `total` is the month's total; the capsule is finished when `total > 0 && reviewed >= total`
    /// and not started while `reviewed` is 0. The three counts are scaled down when they add up to
    /// more than `reviewed`.
    func configure(deleted: Int, kept: Int, stored: Int, total: Int, reviewed: Int) {
        let isFinished = total > 0 && reviewed >= total
        if alwaysShowsSplit && total <= 0 {
            mode = .notStarted
        } else if !alwaysShowsSplit && isFinished {
            mode = .finished
        } else if !alwaysShowsSplit && reviewed <= 0 {
            mode = .notStarted
        } else {
            mode = .inProgress
            var counts = [CGFloat(max(0, deleted)), CGFloat(max(0, kept)), CGFloat(max(0, stored))]
            let decided = counts.reduce(0, +)
            let reviewedValue = CGFloat(max(0, reviewed))
            if decided > reviewedValue, decided > 0 {
                counts = counts.map { $0 * reviewedValue / decided }
            }
            if usesSingleProgressColor {
                // One segment for everything reviewed, in the first layer
                counts = [reviewedValue, 0, 0]
            }
            // With no total yet, what's reviewed is all there is to show
            let left = max(0, CGFloat(total) - reviewedValue)
            segmentValues = counts + [left]
            if segmentValues.reduce(0, +) <= 0 {
                // Everything reviewed with no decision recorded: one plain segment, never nothing
                segmentValues = [0, 0, 0, 1]
            }
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
        stampView.isHidden = mode != .finished
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

        let outlineScale = min(sizeScale, Layout.maximumOutlineScale)
        let outlineWidth = Layout.outlineWidth * outlineScale
        let outlineRect = bounds.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2)
        outlineLayer.frame = bounds
        outlineLayer.lineWidth = outlineWidth
        outlineLayer.lineDashPattern = Layout.outlineDashPattern.map {
            NSNumber(value: Double(CGFloat(truncating: $0) * outlineScale))
        }
        outlineLayer.path = UIBezierPath(roundedRect: outlineRect, cornerRadius: outlineRect.width / 2).cgPath

        CATransaction.commit()

        // The stamp keeps its check at 2.2× the finished capsule's width (22pt at the standard 12)
        stampView.frame = bounds
        stampView.capsuleWidth = max(0, bounds.width - Layout.finishedWidthInset * sizeScale)
    }

    private func layoutSegments() {
        let heights = segmentHeights(barHeight: bounds.height)
        var bottom = bounds.height
        for (index, segment) in segmentLayers.enumerated() {
            let height = heights[index]
            segment.isHidden = height <= 0
            guard height > 0 else { continue }
            segment.frame = CGRect(x: 0, y: bottom - height, width: bounds.width, height: height)
            bottom -= height + segmentGap
        }
    }

    /// Proportional heights with every non-zero segment raised to the minimum; the extra comes
    /// from the largest segment, so the segments and their gaps still add up to `barHeight`.
    private func segmentHeights(barHeight: CGFloat) -> [CGFloat] {
        let sum = segmentValues.reduce(0, +)
        let visibleCount = segmentValues.filter { $0 > 0 }.count
        guard sum > 0, visibleCount > 0 else { return segmentValues.map { _ in 0 } }

        let available = max(0, barHeight - segmentGap * CGFloat(visibleCount - 1))
        let minimumHeight = Layout.minimumSegmentHeight * sizeScale
        var heights = segmentValues.map { available * $0 / sum }
        guard let largestIndex = heights.indices.max(by: { heights[$0] < heights[$1] }) else { return heights }

        var deficit: CGFloat = 0
        for index in heights.indices where index != largestIndex {
            if segmentValues[index] > 0 && heights[index] < minimumHeight {
                deficit += minimumHeight - heights[index]
                heights[index] = minimumHeight
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
        let firstColor = usesSingleProgressColor ? UIColor.label : ThemeManager.Colors.statusRed
        deletedLayer.backgroundColor = firstColor.resolvedColor(with: traitCollection).cgColor
        keptLayer.backgroundColor = green
        storedLayer.backgroundColor = ThemeManager.Colors.statusYellow.resolvedColor(with: traitCollection).cgColor
        leftLayer.backgroundColor = UIColor.systemGray5.resolvedColor(with: traitCollection).cgColor
        outlineLayer.strokeColor = UIColor.systemGray3.resolvedColor(with: traitCollection).cgColor
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

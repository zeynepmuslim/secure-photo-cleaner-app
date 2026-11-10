//
//  DecisionRingView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let reviewed = NSLocalizedString("decisionRing.reviewed", comment: "Label under the percentage inside the progress ring")
    static let notCounted = NSLocalizedString("decisionRing.notCounted", comment: "VoiceOver label of the progress ring before the items are counted")
    static func accessibility(deleted: Int, kept: Int, stored: Int, left: Int) -> String {
        String(
            format: NSLocalizedString(
                "decisionRing.accessibility",
                comment: "VoiceOver summary of the progress ring: deleted, kept, stored and left counts"),
            deleted, kept, stored, left)
    }
}

/// A ring split by choice: one arc each for delete (red), keep (green), store (yellow) and what is
/// left to review (gray), clockwise from 12 o'clock, each in proportion to its count. The center
/// shows the reviewed percentage, or a green checkmark once everything is reviewed.
final class DecisionRingView: UIView {

    private enum Layout {
        /// Stroke width as a share of the diameter.
        static let strokeRatio: CGFloat = 0.09
        /// Gap between neighbouring arcs, along the ring, as a share of the stroke width.
        static let gapRatio: CGFloat = 0.35
        static let percentFontRatio: CGFloat = 0.2
        static let checkmarkRatio: CGFloat = 0.3
        static let captionFontSize: CGFloat = 15
        static let captionMinimumFontSize: CGFloat = 11
        static let captionSpacing: CGFloat = 4
    }

    private struct Segment {
        let count: Int
        let layer: CAShapeLayer
    }

    private let deleteLayer = CAShapeLayer()
    private let keepLayer = CAShapeLayer()
    private let storeLayer = CAShapeLayer()
    private let leftLayer = CAShapeLayer()

    private let percentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        return label
    }()

    private let captionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = Strings.reviewed
        label.font = .systemFont(ofSize: Layout.captionFontSize, weight: .medium)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = Layout.captionMinimumFontSize / Layout.captionFontSize
        return label
    }()

    private let centerStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = Layout.captionSpacing
        return stack
    }()

    private let checkmarkView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()

    private var checkmarkSizeConstraint: NSLayoutConstraint?
    private var centerWidthConstraint: NSLayoutConstraint?

    private var deleted = 0
    private var kept = 0
    private var stored = 0
    private var total = 0
    private var reviewed = 0
    private var appliedDiameter: CGFloat = 0

    private var left: Int { max(0, total - reviewed) }

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
        [deleteLayer, keepLayer, storeLayer, leftLayer].forEach {
            $0.fillColor = UIColor.clear.cgColor
            $0.lineCap = .butt
            layer.addSublayer($0)
        }
        updateColors()

        centerStack.addArrangedSubview(percentLabel)
        centerStack.addArrangedSubview(captionLabel)
        addSubview(centerStack)
        addSubview(checkmarkView)

        isAccessibilityElement = true
        accessibilityTraits = .image

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: DecisionRingView, _: UITraitCollection) in
                self.updateColors()
            }
        }
        applyValues()
    }

    private func setupConstraint() {
        let checkmarkSize = checkmarkView.widthAnchor.constraint(equalToConstant: 0)
        let centerWidth = centerStack.widthAnchor.constraint(lessThanOrEqualToConstant: 0)
        checkmarkSizeConstraint = checkmarkSize
        centerWidthConstraint = centerWidth
        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerWidth,

            checkmarkView.centerXAnchor.constraint(equalTo: centerXAnchor),
            checkmarkView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkSize,
            checkmarkView.heightAnchor.constraint(equalTo: checkmarkView.widthAnchor)
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let diameter = min(bounds.width, bounds.height)
        guard diameter > 0 else { return }
        if diameter != appliedDiameter {
            appliedDiameter = diameter
            applySize(diameter: diameter)
        }
        updatePaths()
    }

    /// Stroke, center fonts and the checkmark all scale with the ring.
    private func applySize(diameter: CGFloat) {
        let stroke = (diameter * Layout.strokeRatio).rounded()
        [deleteLayer, keepLayer, storeLayer, leftLayer].forEach { $0.lineWidth = stroke }
        percentLabel.font = .monospacedDigitSystemFont(
            ofSize: (diameter * Layout.percentFontRatio).rounded(), weight: .bold)
        let checkmarkSize = (diameter * Layout.checkmarkRatio).rounded()
        checkmarkView.image = UIImage(
            systemName: "checkmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: checkmarkSize, weight: .bold))
        checkmarkSizeConstraint?.constant = checkmarkSize
        // The center text stays inside the ring's hole
        centerWidthConstraint?.constant = max(0, diameter - 2 * stroke - 2 * GeneralConstants.EdgePadding.small)
    }

    private func updatePaths() {
        let diameter = min(bounds.width, bounds.height)
        let stroke = deleteLayer.lineWidth
        let radius = (diameter - stroke) / 2
        guard radius > 0 else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let segments = [
            Segment(count: deleted, layer: deleteLayer),
            Segment(count: kept, layer: keepLayer),
            Segment(count: stored, layer: storeLayer),
            Segment(count: left, layer: leftLayer)
        ]
        let visible = segments.filter { $0.count > 0 }
        segments.forEach { $0.layer.path = nil }

        // Before anything is counted the ring is an empty gray track
        guard !visible.isEmpty else {
            leftLayer.path = UIBezierPath(
                arcCenter: center, radius: radius, startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true
            ).cgPath
            return
        }

        // A single choice closes the ring with no gap
        let gapAngle = visible.count > 1 ? (stroke * Layout.gapRatio) / radius : 0
        // The arcs share the ring by their counts, so it always closes
        let sum = CGFloat(visible.reduce(0) { $0 + $1.count })
        var start = -CGFloat.pi / 2
        for segment in visible {
            let sweep = 2 * .pi * CGFloat(segment.count) / sum
            let arcStart = start + gapAngle / 2
            let arcEnd = start + sweep - gapAngle / 2
            if arcEnd > arcStart {
                segment.layer.path = UIBezierPath(
                    arcCenter: center, radius: radius, startAngle: arcStart, endAngle: arcEnd, clockwise: true
                ).cgPath
            }
            start += sweep
        }
    }

    /// CGColors don't follow the appearance, so they're resolved against this view's traits.
    private func updateColors() {
        deleteLayer.strokeColor = ThemeManager.Colors.statusRed.resolvedColor(with: traitCollection).cgColor
        keepLayer.strokeColor = ThemeManager.Colors.statusGreen.resolvedColor(with: traitCollection).cgColor
        storeLayer.strokeColor = ThemeManager.Colors.statusYellow.resolvedColor(with: traitCollection).cgColor
        leftLayer.strokeColor = UIColor.systemGray5.resolvedColor(with: traitCollection).cgColor
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    // MARK: - Configure

    /// Counts come clamped by the caller. `reviewed` defaults to `deleted + kept + stored`; what is
    /// left is `total − reviewed`. A `total` of 0 (not counted yet) shows an empty ring and "–".
    func configure(deleted: Int, kept: Int, stored: Int, total: Int, reviewed: Int? = nil, animated: Bool) {
        let total = max(0, total)
        let reviewed = min(total, max(0, reviewed ?? (deleted + kept + stored)))
        let newValues = (max(0, deleted), max(0, kept), max(0, stored), total, reviewed)
        guard newValues != (self.deleted, self.kept, self.stored, self.total, self.reviewed) else { return }
        (self.deleted, self.kept, self.stored, self.total, self.reviewed) = newValues

        let apply = {
            self.applyValues()
            self.updatePaths()
        }
        if animated && window != nil {
            UIView.transition(with: self, duration: 0.25, options: .transitionCrossDissolve, animations: apply)
        } else {
            apply()
        }
    }

    private func applyValues() {
        let isComplete = total > 0 && left == 0
        checkmarkView.isHidden = !isComplete
        centerStack.isHidden = isComplete

        if total > 0 {
            percentLabel.text = Self.percentText(reviewed: reviewed, total: total)
            accessibilityLabel = Strings.accessibility(deleted: deleted, kept: kept, stored: stored, left: left)
        } else {
            percentLabel.text = "–"
            accessibilityLabel = Strings.notCounted
        }
    }

    /// Rounded down, so 99.6% never reads as 100% while something is left.
    private static func percentText(reviewed: Int, total: Int) -> String {
        let percent = (Double(reviewed) / Double(total) * 100).rounded(.down) / 100
        return percentFormatter.string(from: NSNumber(value: percent)) ?? "\(Int(percent * 100))%"
    }

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct DecisionRingPreview: UIViewRepresentable {
        let values: (deleted: Int, kept: Int, stored: Int, total: Int)

        func makeUIView(context: Context) -> DecisionRingView {
            let ring = DecisionRingView()
            ring.configure(
                deleted: values.deleted, kept: values.kept, stored: values.stored, total: values.total,
                animated: false)
            return ring
        }

        func updateUIView(_ uiView: DecisionRingView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Decision ring") {
        VStack(spacing: 24) {
            DecisionRingPreview(values: (5, 13, 3, 29)).frame(width: 220, height: 220)
            HStack(spacing: 24) {
                DecisionRingPreview(values: (4, 10, 0, 14)).frame(width: 120, height: 120)
                DecisionRingPreview(values: (0, 0, 0, 0)).frame(width: 120, height: 120)
            }
        }
        .padding(40)
        .background(Color(UIColor.cardBackground))
    }
#endif

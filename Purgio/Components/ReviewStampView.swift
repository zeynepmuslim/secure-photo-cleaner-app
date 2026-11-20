//
//  ReviewStampView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

/// The review stamp: a vertical green capsule with a white check, rotated and wider than the
/// capsule, once something is fully reviewed; a dashed outline before it's started.
/// `ReviewCapsuleView` shows it when finished, and the end states use it as their hero.
///
/// Every attribute can be set at any time; the stamp lays out again. The check's border
/// separates it from the capsule: the capsule's green in light mode, the surface behind the
/// stamp in dark mode (the dark green is too bright for a white check on it alone).
final class ReviewStampView: UIView {

    enum Status {
        /// The green capsule stamped with the check
        case done
        /// A dashed outline
        case notStarted
    }

    private enum Layout {
        static let size = CGSize(width: 10, height: 40)
        /// The check box is this many times the capsule's width
        static let checkSizeRatio: CGFloat = 2.2
        /// The check is drawn in a 24-unit box: "M5 12.5 l4.5 4.5 L19 7"
        static let checkUnitBox: CGFloat = 24
        static let checkBorderStroke: CGFloat = 7.5
        static let checkCoreStroke: CGFloat = 3.6
        static let checkRotation: CGFloat = -8 * .pi / 180
        /// The dashed outline at a 12pt-wide capsule; it scales with the width up to twice that
        static let outlineReferenceWidth: CGFloat = 12
        static let maximumOutlineScale: CGFloat = 2
        static let outlineWidth: CGFloat = 1.5
        static let outlineDashPattern: [CGFloat] = [3, 2.5]
    }

    // MARK: - Attributes

    var status: Status = .done {
        didSet { if status != oldValue { applyStatus() } }
    }

    /// The capsule's width, centered in the view; nil fills the view's width
    var capsuleWidth: CGFloat? {
        didSet { if capsuleWidth != oldValue { setNeedsLayout() } }
    }

    /// The check's box side; nil is `checkSizeRatio` (2.2) times the capsule's width
    var checkSize: CGFloat? {
        didSet { if checkSize != oldValue { setNeedsLayout() } }
    }

    var capsuleColor: UIColor = ThemeManager.Colors.statusGreen {
        didSet { applyColors() }
    }

    var checkColor: UIColor = .white {
        didSet { applyColors() }
    }

    /// The check's border; nil is the capsule's color in light mode and `.cardBackground` in
    /// dark mode. A stamp on another surface passes that surface (the end states: `.mainBackground`).
    var checkBorderColor: UIColor? {
        didSet { applyColors() }
    }

    // MARK: - Layers

    private let capsuleLayer: CALayer = {
        let layer = CALayer()
        layer.cornerCurve = .continuous
        return layer
    }()

    private let outlineLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        return layer
    }()

    private let checkContainerLayer = CALayer()
    private let checkBorderLayer = ReviewStampView.makeCheckLayer()
    private let checkCoreLayer = ReviewStampView.makeCheckLayer()

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
        // The check is wider than the capsule
        clipsToBounds = false
        isAccessibilityElement = false
        isUserInteractionEnabled = false

        layer.addSublayer(outlineLayer)
        layer.addSublayer(capsuleLayer)
        layer.addSublayer(checkContainerLayer)
        checkContainerLayer.addSublayer(checkBorderLayer)
        checkContainerLayer.addSublayer(checkCoreLayer)

        applyColors()
        applyStatus()

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: ReviewStampView, _: UITraitCollection) in
                self.applyColors()
            }
        }
    }

    /// The check's path in a 1×1 box; the layout scales it to the check's size.
    private static func makeCheckLayer() -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let width = min(capsuleWidth ?? bounds.width, bounds.width)
        let capsuleRect = CGRect(x: (bounds.width - width) / 2, y: 0, width: width, height: bounds.height)
        capsuleLayer.frame = capsuleRect
        capsuleLayer.cornerRadius = width / 2

        let outlineScale = min(width / Layout.outlineReferenceWidth, Layout.maximumOutlineScale)
        let outlineWidth = Layout.outlineWidth * outlineScale
        let outlineRect = capsuleRect.insetBy(dx: outlineWidth / 2, dy: outlineWidth / 2)
        outlineLayer.frame = bounds
        outlineLayer.lineWidth = outlineWidth
        outlineLayer.lineDashPattern = Layout.outlineDashPattern.map { NSNumber(value: Double($0 * outlineScale)) }
        outlineLayer.path = UIBezierPath(roundedRect: outlineRect, cornerRadius: outlineRect.width / 2).cgPath

        let side = checkSize ?? width * Layout.checkSizeRatio
        let unit = side / Layout.checkUnitBox
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 5, y: 12.5))
        path.addLine(to: CGPoint(x: 9.5, y: 17))
        path.addLine(to: CGPoint(x: 19, y: 7))
        path.apply(CGAffineTransform(scaleX: unit, y: unit))
        let box = CGRect(x: 0, y: 0, width: side, height: side)
        for (checkLayer, stroke) in [(checkBorderLayer, Layout.checkBorderStroke), (checkCoreLayer, Layout.checkCoreStroke)] {
            checkLayer.frame = box
            checkLayer.path = path.cgPath
            checkLayer.lineWidth = stroke * unit
        }
        // Bounds and position, not frame: the layer is rotated
        checkContainerLayer.bounds = box
        checkContainerLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        checkContainerLayer.setAffineTransform(CGAffineTransform(rotationAngle: Layout.checkRotation))

        CATransaction.commit()
    }

    // MARK: - Appearance

    private func applyStatus() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        capsuleLayer.isHidden = status != .done
        checkContainerLayer.isHidden = status != .done
        outlineLayer.isHidden = status != .notStarted
        CATransaction.commit()
    }

    private func applyColors() {
        let capsule = capsuleColor.resolvedColor(with: traitCollection)
        let border = checkBorderColor
            ?? (traitCollection.userInterfaceStyle == .dark ? UIColor.cardBackground : capsuleColor)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        capsuleLayer.backgroundColor = capsule.cgColor
        checkBorderLayer.strokeColor = border.resolvedColor(with: traitCollection).cgColor
        checkCoreLayer.strokeColor = checkColor.resolvedColor(with: traitCollection).cgColor
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

private struct ReviewStampPreview: UIViewRepresentable {
    var status: ReviewStampView.Status = .done
    var capsuleWidth: CGFloat?
    var checkSize: CGFloat?

    func makeUIView(context: Context) -> ReviewStampView {
        let view = ReviewStampView()
        view.status = status
        view.capsuleWidth = capsuleWidth
        view.checkSize = checkSize
        return view
    }

    func updateUIView(_ uiView: ReviewStampView, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Review stamp") {
    HStack(spacing: 32) {
        ReviewStampPreview().frame(width: 10, height: 40)
        ReviewStampPreview(status: .notStarted).frame(width: 12, height: 40)
        ReviewStampPreview().frame(width: 40, height: 120)
        ReviewStampPreview(capsuleWidth: 24, checkSize: 40).frame(width: 40, height: 120)
    }
    .padding(40)
    .background(Color(uiColor: .cardBackground))
}
#endif

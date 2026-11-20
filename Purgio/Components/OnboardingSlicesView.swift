//
//  OnboardingSlicesView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 19.11.2026.
//

import UIKit

/// The onboarding swipe guide's pie: three equal 120° slices, Store on top, Keep lower right and
/// Delete lower left, each holding its arrow over its label. Every corner is rounded by the same
/// radius and the gaps between slices are even. Decorative for VoiceOver (the rules carry the meaning).
final class OnboardingSlicesView: UIView {

    private enum Layout {
        /// The design's diameter; every other metric scales from it.
        static let referenceDiameter: CGFloat = 228
        static let cornerRadius: CGFloat = 14
        static let gap: CGFloat = 8
        static let arrowSize: CGFloat = 30
        static let labelSize: CGFloat = 15
        static let contentSpacing: CGFloat = 2
        /// Where a slice's content sits along its bisector, as a share of the radius.
        static let contentDistance: CGFloat = 0.56
        static let halfSliceAngle: CGFloat = .pi / 3
    }

    private struct Slice {
        /// Bisector angle in radians, clockwise from 3 o'clock (UIKit's y-down space).
        let angle: CGFloat
        let color: UIColor
        let arrowName: String
        let ink: UIColor
        let shapeLayer = CAShapeLayer()
        let arrowView: UIImageView
        let label: UILabel
        let contentStack: UIStackView
        var centerX: NSLayoutConstraint?
        var centerY: NSLayoutConstraint?

        init(angle: CGFloat, color: UIColor, arrowName: String, ink: UIColor) {
            self.angle = angle
            self.color = color
            self.arrowName = arrowName
            self.ink = ink

            let arrow = UIImageView()
            arrow.tintColor = ink
            arrow.contentMode = .center
            arrowView = arrow

            let text = UILabel()
            text.textColor = ink
            text.textAlignment = .center
            text.adjustsFontSizeToFitWidth = true
            text.minimumScaleFactor = 0.7
            label = text

            let stack = UIStackView(arrangedSubviews: [arrow, text])
            stack.axis = .vertical
            stack.alignment = .center
            stack.spacing = Layout.contentSpacing
            stack.translatesAutoresizingMaskIntoConstraints = false
            contentStack = stack
        }
    }

    private var slices: [Slice] = [
        Slice(angle: -.pi / 2, color: ThemeManager.Colors.statusYellow, arrowName: "arrow.up", ink: .inkOnYellow),
        Slice(angle: .pi / 6, color: ThemeManager.Colors.statusGreen, arrowName: "arrow.right", ink: .white),
        Slice(angle: 5 * .pi / 6, color: ThemeManager.Colors.statusRed, arrowName: "arrow.left", ink: .white),
    ]

    private var diameterConstraint: NSLayoutConstraint?
    private var appliedScale: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        // Keep right and Delete left are physical, like the swipe itself.
        semanticContentAttribute = .forceLeftToRight
        isAccessibilityElement = false
        accessibilityElementsHidden = true

        for index in slices.indices {
            let slice = slices[index]
            slice.shapeLayer.lineJoin = .round
            slice.shapeLayer.lineCap = .round
            layer.addSublayer(slice.shapeLayer)
            addSubview(slice.contentStack)

            let centerX = slice.contentStack.centerXAnchor.constraint(equalTo: centerXAnchor)
            let centerY = slice.contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
            NSLayoutConstraint.activate([centerX, centerY])
            slices[index].centerX = centerX
            slices[index].centerY = centerY
        }

        let diameter = widthAnchor.constraint(equalToConstant: Layout.referenceDiameter)
        NSLayoutConstraint.activate([
            diameter,
            heightAnchor.constraint(equalTo: widthAnchor),
        ])
        diameterConstraint = diameter

        updateColors()
        applyScale(1)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: OnboardingSlicesView, _: UITraitCollection) in
                self.updateColors()
            }
        }
    }

    // MARK: - Configure

    func configure(storeTitle: String, keepTitle: String, deleteTitle: String) {
        slices[0].label.text = storeTitle
        slices[1].label.text = keepTitle
        slices[2].label.text = deleteTitle
    }

    var diameter: CGFloat {
        diameterConstraint?.constant ?? Layout.referenceDiameter
    }

    /// Sets the pie's diameter; the corner radius, the gaps, the arrows and the labels scale with it.
    func setDiameter(_ diameter: CGFloat) {
        guard let constraint = diameterConstraint, abs(constraint.constant - diameter) > 0.5 else { return }
        constraint.constant = diameter
        applyScale(diameter / Layout.referenceDiameter)
        setNeedsLayout()
    }

    private func applyScale(_ scale: CGFloat) {
        guard abs(appliedScale - scale) > 0.001 else { return }
        appliedScale = scale
        let arrowConfig = UIImage.SymbolConfiguration(pointSize: Layout.arrowSize * scale, weight: .bold)
        let labelFont = ThemeManager.Fonts.titleFont(size: Layout.labelSize * scale, weight: .heavy)
        for slice in slices {
            slice.arrowView.image = UIImage(systemName: slice.arrowName, withConfiguration: arrowConfig)
            slice.label.font = labelFont
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = min(bounds.width, bounds.height)
        guard size > 0 else { return }

        let scale = size / Layout.referenceDiameter
        let radius = Layout.cornerRadius * scale
        let inset = Layout.gap * scale / 2 + radius
        let outerRadius = size / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for slice in slices {
            slice.shapeLayer.frame = bounds
            slice.shapeLayer.lineWidth = 2 * radius
            slice.shapeLayer.path = Self.slicePath(
                center: center, outerRadius: outerRadius, bisector: slice.angle, inset: inset)

            let distance = outerRadius * Layout.contentDistance
            slice.centerX?.constant = cos(slice.angle) * distance
            slice.centerY?.constant = sin(slice.angle) * distance
            // The label never runs past the slice's width at its content line.
            slice.label.preferredMaxLayoutWidth = outerRadius
        }
    }

    /// The slice inset by `inset` on every side: its two straight edges are the slice's rays moved
    /// inward, ending where they meet the circle of radius `outerRadius − inset`. Stroked with
    /// `lineWidth = 2 × radius` and round joins, every corner rounds by the same radius.
    private static func slicePath(center: CGPoint, outerRadius: CGFloat, bisector: CGFloat, inset: CGFloat) -> CGPath {
        let half = Layout.halfSliceAngle
        let apexDistance = inset / sin(half)
        let apex = CGPoint(x: center.x + cos(bisector) * apexDistance, y: center.y + sin(bisector) * apexDistance)
        let arcRadius = max(outerRadius - inset, apexDistance + 1)

        func edgeEnd(rayAngle: CGFloat) -> CGFloat {
            // Solve |a + t·e| = arcRadius for t > 0, a = apex − center, e = the ray's direction.
            let ax = apex.x - center.x
            let ay = apex.y - center.y
            let ex = cos(rayAngle)
            let ey = sin(rayAngle)
            let b = ax * ex + ay * ey
            let c = ax * ax + ay * ay - arcRadius * arcRadius
            let t = -b + sqrt(max(b * b - c, 0))
            return atan2(ay + t * ey, ax + t * ex)
        }

        let startAngle = edgeEnd(rayAngle: bisector - half)
        let endAngle = edgeEnd(rayAngle: bisector + half)

        let path = UIBezierPath()
        path.move(to: apex)
        path.addLine(to: CGPoint(x: center.x + cos(startAngle) * arcRadius, y: center.y + sin(startAngle) * arcRadius))
        path.addArc(withCenter: center, radius: arcRadius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.close()
        return path.cgPath
    }

    // MARK: - Colors

    /// CGColors don't follow the appearance, so they're resolved against this view's traits.
    private func updateColors() {
        for slice in slices {
            let color = slice.color.resolvedColor(with: traitCollection).cgColor
            slice.shapeLayer.fillColor = color
            slice.shapeLayer.strokeColor = color
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    // MARK: - Strings

    private enum Strings {
        static let store = NSLocalizedString("onboarding.store", comment: "Store slice label in the swipe guide")
        static let keep = NSLocalizedString("onboarding.keep", comment: "Keep slice label in the swipe guide")
    }

    @available(iOS 17.0, *)
    private struct OnboardingSlicesPreview: UIViewRepresentable {
        let diameter: CGFloat

        func makeUIView(context: Context) -> UIView {
            let container = UIView()
            let slices = OnboardingSlicesView()
            slices.configure(
                storeTitle: Strings.store,
                keepTitle: Strings.keep,
                deleteTitle: CommonStrings.delete)
            slices.setDiameter(diameter)
            container.addSubview(slices)
            NSLayoutConstraint.activate([
                slices.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                slices.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
            return container
        }

        func updateUIView(_ uiView: UIView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Slices") {
        VStack(spacing: 24) {
            OnboardingSlicesPreview(diameter: 228).frame(width: 260, height: 260)
            OnboardingSlicesPreview(diameter: 150).frame(width: 180, height: 180)
        }
    }
#endif

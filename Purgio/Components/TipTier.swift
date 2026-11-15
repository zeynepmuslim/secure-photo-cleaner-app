//
//  TipTier.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.04.2026.
//

import UIKit

/// One tip tier: a vertical capsule whose height says the amount, with the tier's name and
/// price under it. Unchosen it's neutral gray with a red icon; chosen it's solid red.
///
/// The row lays the tiers out: it hands every tier the same capsule area through
/// `setCapsuleSize(width:areaHeight:)`, and each capsule takes `heightRatio` of it, bottom-aligned.
final class TipTier: UIControl {

    private(set) var isCardSelected: Bool = false

    /// The unchosen capsule's fill. The sheet sets it to stand out from whatever is behind it:
    /// the default suits glass and grouped backgrounds, not an opaque white sheet.
    var restingColor: UIColor = .secondarySystemGroupedBackground {
        didSet { if !isCardSelected { capsuleView.backgroundColor = restingColor } }
    }

    /// The capsule's share of the row's capsule area (small 0.5, medium 0.75, large 1).
    var heightRatio: CGFloat = 1 {
        didSet { applyCapsuleSize() }
    }

    override var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UIView.animate(withDuration: 0.2) {
                self.alpha = self.isEnabled ? 1.0 : 0.5
            }
        }
    }

    private enum Layout {
        static let imageTopInset: CGFloat = 20
        static let capsuleToTitle: CGFloat = 10
        static let titleToPrice: CGFloat = 2
    }

    private let imageSize: CGFloat
    private var capsuleWidth: CGFloat = GeneralConstants.TipCapsule.width
    private var capsuleAreaHeight: CGFloat = GeneralConstants.TipCapsule.maximumHeight

    private var capsuleWidthConstraint: NSLayoutConstraint?
    private var capsuleHeightConstraint: NSLayoutConstraint?
    private var capsuleBottomConstraint: NSLayoutConstraint?
    private var imageTopConstraint: NSLayoutConstraint?
    private var imageSizeConstraints: [NSLayoutConstraint] = []

    private let capsuleView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerCurve = .continuous
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private let symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tipJarRed100
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .secondaryLabel
        label.isUserInteractionEnabled = false
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    init(title: String, imageName: String, imageSize: CGFloat, price: String) {
        self.imageSize = imageSize
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        priceLabel.text = price
        symbolImageView.image = UIImage(named: imageName)?.withRenderingMode(.alwaysTemplate)

        isAccessibilityElement = true
        // VoiceOver reads the label, then the value: "Small Tip, $0.99".
        accessibilityLabel = title.replacingOccurrences(of: "\n", with: " ")
        accessibilityValue = price
        accessibilityTraits = .button

        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(capsuleView)
        capsuleView.addSubview(symbolImageView)
        addSubview(titleLabel)
        addSubview(priceLabel)
    }

    private func setupConstraint() {
        let width = capsuleView.widthAnchor.constraint(equalToConstant: capsuleWidth)
        let height = capsuleView.heightAnchor.constraint(equalToConstant: capsuleAreaHeight)
        let bottom = capsuleView.bottomAnchor.constraint(equalTo: topAnchor, constant: capsuleAreaHeight)
        let imageTop = symbolImageView.topAnchor.constraint(equalTo: capsuleView.topAnchor, constant: Layout.imageTopInset)
        imageSizeConstraints = [
            symbolImageView.widthAnchor.constraint(equalToConstant: imageSize),
            symbolImageView.heightAnchor.constraint(equalToConstant: imageSize),
        ]
        capsuleWidthConstraint = width
        capsuleHeightConstraint = height
        capsuleBottomConstraint = bottom
        imageTopConstraint = imageTop

        NSLayoutConstraint.activate([
            width, height, bottom, imageTop,
            capsuleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            capsuleView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),

            symbolImageView.centerXAnchor.constraint(equalTo: capsuleView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: capsuleView.bottomAnchor, constant: Layout.capsuleToTitle),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            priceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.titleToPrice),
            priceLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            priceLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            priceLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ] + imageSizeConstraints)
    }

    // MARK: - Sizing

    /// Every tier in a row gets the same width and capsule area; the capsule is
    /// `heightRatio` of the area, never shorter than its width, bottom-aligned in it.
    func setCapsuleSize(width: CGFloat, areaHeight: CGFloat) {
        capsuleWidth = width
        capsuleAreaHeight = areaHeight
        applyCapsuleSize()
    }

    private func applyCapsuleSize() {
        let height = max(capsuleWidth, (capsuleAreaHeight * heightRatio).rounded())
        capsuleWidthConstraint?.constant = capsuleWidth
        capsuleHeightConstraint?.constant = height
        capsuleBottomConstraint?.constant = capsuleAreaHeight

        // The icon sits 20pt from the top; in a narrow capsule it shrinks and centers in the round end.
        let icon = min(imageSize, capsuleWidth * 0.5)
        imageSizeConstraints.forEach { $0.constant = icon }
        imageTopConstraint?.constant = min(Layout.imageTopInset, (capsuleWidth - icon) / 2)
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A true capsule at any size (a lens shape when the radius follows only the width).
        capsuleView.layer.cornerRadius = min(capsuleView.bounds.width, capsuleView.bounds.height) / 2
    }

    // MARK: - Selection

    func setSelected(_ selected: Bool, animated: Bool = true) {
        guard isCardSelected != selected else { return }
        isCardSelected = selected
        accessibilityTraits = selected ? [.button, .selected] : .button

        let apply = {
            self.capsuleView.backgroundColor = selected ? .tipJarRed100 : self.restingColor
            self.symbolImageView.tintColor = selected ? .white : .tipJarRed100
        }

        guard animated else {
            apply()
            return
        }

        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.8,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: { self.capsuleView.backgroundColor = selected ? .tipJarRed100 : self.restingColor }
        )
        // The tint doesn't animate in a block; cross-dissolve it alongside.
        UIView.transition(with: symbolImageView, duration: 0.25, options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.symbolImageView.tintColor = selected ? .white : .tipJarRed100
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard isEnabled, let touch = touches.first else { return }
        let location = touch.location(in: self)
        if bounds.contains(location) {
            sendActions(for: .touchUpInside)
        }
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
private struct TipTierRowPreview: UIViewRepresentable {
    let selectedIndex: Int?

    func makeUIView(context: Context) -> UIStackView {
        let tiers: [(String, String, CGFloat, String, CGFloat)] = [
            ("Small\nTip", "small-tip", 26, "$0.99", 0.5),
            ("Medium\nTip", "mid-tip", 34, "$2.99", 0.75),
            ("Large\nTip", "large-tip", 30, "$4.99", 1),
        ]
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .top
        stack.distribution = .fillEqually
        stack.spacing = GeneralConstants.TipCapsule.spacing
        for (index, tier) in tiers.enumerated() {
            let view = TipTier(title: tier.0, imageName: tier.1, imageSize: tier.2, price: tier.3)
            view.heightRatio = tier.4
            view.setCapsuleSize(width: GeneralConstants.TipCapsule.width, areaHeight: GeneralConstants.TipCapsule.maximumHeight)
            view.setSelected(index == selectedIndex, animated: false)
            stack.addArrangedSubview(view)
        }
        return stack
    }

    func updateUIView(_ uiView: UIStackView, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Tiers") {
    TipTierRowPreview(selectedIndex: 1)
        .frame(height: 280)
        .padding()
}

@available(iOS 17.0, *)
#Preview("Tiers — Dark") {
    TipTierRowPreview(selectedIndex: nil)
        .frame(height: 280)
        .padding()
        .preferredColorScheme(.dark)
}
#endif

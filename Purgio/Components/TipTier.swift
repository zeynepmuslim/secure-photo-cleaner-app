//
//  TipTier.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.04.2026.
//

import UIKit

final class TipTier: UIControl {

    private(set) var isCardSelected: Bool = false

    func setSelected(_ selected: Bool) {
        guard isCardSelected != selected else { return }
        isCardSelected = selected

        let targetColor = (selected ? UIColor.tipJarRed100 : Self.defaultBorderColor).cgColor
        let targetWidth: CGFloat = selected ? Self.selectedBorderWidth : Self.defaultBorderWidth

        let colorAnimation = CABasicAnimation(keyPath: "borderColor")
        colorAnimation.fromValue = containerView.layer.borderColor
        colorAnimation.toValue = targetColor
        colorAnimation.duration = 0.4
        colorAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        containerView.layer.add(colorAnimation, forKey: "borderColor")
        containerView.layer.borderColor = targetColor

        let widthAnimation = CABasicAnimation(keyPath: "borderWidth")
        widthAnimation.fromValue = containerView.layer.borderWidth
        widthAnimation.toValue = targetWidth
        widthAnimation.duration = 0.4
        widthAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        containerView.layer.add(widthAnimation, forKey: "borderWidth")
        containerView.layer.borderWidth = targetWidth
    }

    override var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            UIView.animate(withDuration: 0.2) {
                self.alpha = self.isEnabled ? 1.0 : 0.5
            }
        }
    }

    private static let legacyCornerRadius: CGFloat = 16

    private static let defaultBorderColor: UIColor = .label.withAlphaComponent(0.12)
    private static let defaultBorderWidth: CGFloat = 1
    private static let selectedBorderWidth: CGFloat = 1
    private static let minHeight: CGFloat = 140

    private let containerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .cardBackground
        view.layer.masksToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }()

    private let symbolImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .center
        imageView.tintColor = .tipJarRed100
        imageView.setContentHuggingPriority(.required, for: .vertical)
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .vertical)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.numberOfLines = 2
        label.font = ThemeManager.Fonts.semiboldBody
        label.textColor = .textPrimary
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let priceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .textSecondary
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        stack.isUserInteractionEnabled = false
        return stack
    }()

    init(title: String, symbol: String, symbolSize: CGFloat, price: String) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        priceLabel.text = price
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
        symbolImageView.image = UIImage(systemName: symbol, withConfiguration: symbolConfig)

        containerView.layer.borderColor = Self.defaultBorderColor.cgColor
        containerView.layer.borderWidth = Self.defaultBorderWidth
        if #available(iOS 26.0, *) {
            // capsule — resolved in layoutSubviews once height is known
        } else {
            containerView.layer.cornerRadius = Self.legacyCornerRadius
        }

        addSubview(containerView)
        containerView.addSubview(contentStack)
        contentStack.addArrangedSubview(symbolImageView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.addArrangedSubview(priceLabel)
        contentStack.setCustomSpacing(14, after: symbolImageView)
        contentStack.setCustomSpacing(4, after: titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minHeight),

            containerView.topAnchor.constraint(equalTo: topAnchor),
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: containerView.topAnchor, constant: 20),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -20),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if #available(iOS 26.0, *) {
            containerView.layer.cornerRadius = containerView.bounds.width / 2
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
private struct TipTierPreviewWrapper: UIViewRepresentable {
    let title: String
    let symbol: String
    let symbolSize: CGFloat
    let price: String
    let selected: Bool

    func makeUIView(context: Context) -> TipTier {
        let view = TipTier(title: title, symbol: symbol, symbolSize: symbolSize, price: price)
        view.setSelected(selected)
        return view
    }

    func updateUIView(_ uiView: TipTier, context: Context) {
        uiView.setSelected(selected)
    }
}

@available(iOS 17.0, *)
#Preview("All Tiers") {
    HStack(spacing: 12) {
        TipTierPreviewWrapper(title: "Small Tip", symbol: "sparkle", symbolSize: 28, price: "₺34,99", selected: false)
        TipTierPreviewWrapper(title: "Medium Tip", symbol: "sparkles", symbolSize: 34, price: "₺94,99", selected: true)
        TipTierPreviewWrapper(title: "Large Tip", symbol: "wand.and.sparkles.inverse", symbolSize: 40, price: "₺159,99", selected: false)
    }
    .frame(height: 160)
    .padding()
}

@available(iOS 17.0, *)
#Preview("All Tiers — Dark") {
    HStack(spacing: 12) {
        TipTierPreviewWrapper(title: "Small Tip", symbol: "sparkle", symbolSize: 28, price: "₺34,99", selected: false)
        TipTierPreviewWrapper(title: "Medium Tip", symbol: "sparkles", symbolSize: 34, price: "₺94,99", selected: true)
        TipTierPreviewWrapper(title: "Large Tip", symbol: "wand.and.sparkles.inverse", symbolSize: 40, price: "₺159,99", selected: false)
    }
    .frame(height: 160)
    .padding()
    .preferredColorScheme(.dark)
}
#endif

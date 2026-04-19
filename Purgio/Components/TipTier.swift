//
//  TipTier.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.04.2026.
//

import UIKit

final class TipTier: UIButton {

    private(set) var isCardSelected: Bool = false

    func setSelected(_ selected: Bool) {
        guard isCardSelected != selected else { return }
        isCardSelected = selected
        var config = configuration
        config?.background.strokeColor = selected ? .tipJarRed100 : Self.defaultBorderColor
        config?.background.strokeWidth = selected ? Self.selectedBorderWidth : Self.defaultBorderWidth
        UIView.animate(
            withDuration: 0.4,
            delay: 0,
            options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction],
            animations: { self.configuration = config }
        )
    }

    private static let cornerRadius: CGFloat = 16

    private static let defaultBorderColor: UIColor = .label.withAlphaComponent(0.12)
    private static let defaultBorderWidth: CGFloat = 1
    private static let selectedBorderWidth: CGFloat = 1
    private static let minHeight: CGFloat = 140

    init(title: String, symbol: String, symbolSize: CGFloat, price: String) {
        super.init(frame: .zero)
        setupConfiguration(title: title, symbol: symbol, symbolSize: symbolSize, price: price)
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: Self.minHeight).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupConfiguration(title: String, symbol: String, symbolSize: CGFloat, price: String) {
        var config: UIButton.Configuration

        if #available(iOS 26.0, *) {
            config = UIButton.Configuration.glass()
            tintColor = .tipJarRed100
        } else {
            config = UIButton.Configuration.filled()
            config.baseBackgroundColor = .cardBackground
        }

        config.baseForegroundColor = .label
        config.background.cornerRadius = Self.cornerRadius
        config.background.strokeColor = Self.defaultBorderColor
        config.background.strokeWidth = Self.defaultBorderWidth

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: symbolSize, weight: .semibold)
        config.image = UIImage(systemName: symbol, withConfiguration: symbolConfig)
        config.imagePlacement = .top
        config.imagePadding = 14
        config.imageColorTransformer = UIConfigurationColorTransformer { _ in .tipJarRed100 }

        var titleAttr = AttributedString(title)
        titleAttr.font = ThemeManager.Fonts.semiboldBody
        titleAttr.foregroundColor = .textPrimary
        config.attributedTitle = titleAttr

        var subtitleAttr = AttributedString(price)
        subtitleAttr.font = ThemeManager.Fonts.regularCaption
        subtitleAttr.foregroundColor = .textSecondary
        config.attributedSubtitle = subtitleAttr

        config.titleAlignment = .center
        config.titlePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 8, bottom: 20, trailing: 8)

        configuration = config

        configurationUpdateHandler = { button in
            UIView.animate(withDuration: 0.2) {
                button.alpha = button.isEnabled ? 1.0 : 0.5
            }
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
        TipTierPreviewWrapper(title: "Large Tip", symbol: "wand.and.stars", symbolSize: 40, price: "₺159,99", selected: false)
    }
    .frame(height: 160)
    .padding()
}

@available(iOS 17.0, *)
#Preview("All Tiers — Dark") {
    HStack(spacing: 12) {
        TipTierPreviewWrapper(title: "Small Tip", symbol: "sparkle", symbolSize: 28, price: "₺34,99", selected: false)
        TipTierPreviewWrapper(title: "Medium Tip", symbol: "sparkles", symbolSize: 34, price: "₺94,99", selected: true)
        TipTierPreviewWrapper(title: "Large Tip", symbol: "wand.and.stars", symbolSize: 40, price: "₺159,99", selected: false)
    }
    .frame(height: 160)
    .padding()
    .preferredColorScheme(.dark)
}
#endif

//
//  CardTitleRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.11.2026.
//

import UIKit

/// A card's title row: an optional colored SF Symbol (no background) beside a wrapping title.
/// At the standard 15pt semibold the glyph is 20pt medium in a 24pt box, 12pt from the title;
/// a larger font (the storage sheet's title) scales the glyph and its box with it.
/// One VoiceOver element: the title, as a header.
final class CardTitleRowView: UIView {

    private enum Layout {
        static let standardFontSize: CGFloat = 15
        static let standardSymbolSize: CGFloat = 20
        static let standardIconBox: CGFloat = 24
        static let spacing: CGFloat = 12
    }

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.standardFontSize, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let stack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.spacing
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var symbolName: String?
    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?

    // MARK: - Init

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
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .header

        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        addSubview(stack)
    }

    private func setupConstraint() {
        let iconWidth = iconView.widthAnchor.constraint(equalToConstant: Layout.standardIconBox)
        let iconHeight = iconView.heightAnchor.constraint(equalToConstant: Layout.standardIconBox)
        iconWidthConstraint = iconWidth
        iconHeightConstraint = iconHeight

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            iconWidth,
            iconHeight
        ])
    }

    // MARK: - Configuration

    /// A nil `symbolName` shows the title alone
    func configure(symbolName: String? = nil, tintColor: UIColor = .label, title: String) {
        self.symbolName = symbolName
        iconView.isHidden = symbolName == nil
        iconView.tintColor = tintColor
        titleLabel.text = title
        accessibilityLabel = title
        applySymbol()
    }

    /// The title's font; the glyph and its box scale with its point size
    func setTitleFont(_ font: UIFont) {
        titleLabel.font = font
        applySymbol()
    }

    private func applySymbol() {
        let scale = titleLabel.font.pointSize / Layout.standardFontSize
        iconWidthConstraint?.constant = Layout.standardIconBox * scale
        iconHeightConstraint?.constant = Layout.standardIconBox * scale
        guard let symbolName else { return }
        let config = UIImage.SymbolConfiguration(
            pointSize: Layout.standardSymbolSize * scale, weight: .medium)
        iconView.image = UIImage(systemName: symbolName, withConfiguration: config)
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview("Card title row") {
    let row = CardTitleRowView()
    row.configure(symbolName: "internaldrive.fill", tintColor: .systemBlue, title: "Storage")
    let large = CardTitleRowView()
    large.configure(title: "Storage")
    large.setTitleFont(ThemeManager.Fonts.titleFont(size: 24, weight: .heavy))
    let stack = UIStackView(arrangedSubviews: [row, large])
    stack.axis = .vertical
    stack.spacing = 20
    stack.alignment = .leading
    return stack
}
#endif

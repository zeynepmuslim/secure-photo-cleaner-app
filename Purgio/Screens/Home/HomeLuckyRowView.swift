//
//  HomeLuckyRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let title = NSLocalizedString("home.luckyItem", comment: "Lucky bar item title (random month and filter)")
    static let subtitle = NSLocalizedString("home.luckySubtitle", comment: "Lucky row subtitle on Home")
}

/// Home's "Feeling Lucky" row on the iPhone Duo's inner display (board HomeDuo-v4): a plain dice,
/// the title over a short note, and a chevron. It does what the Lucky bar item does.
final class HomeLuckyRowView: UIControl {

    private enum Layout {
        static let height: CGFloat = 64
        static let sidePadding: CGFloat = 16
        static let spacing: CGFloat = 12
        static let iconPointSize: CGFloat = 24
        static let titleSize: CGFloat = 16
        static let subtitleSize: CGFloat = 12
        static let textSpacing: CGFloat = 2
        static let chevronPointSize: CGFloat = 12
    }

    var onTap: (() -> Void)?

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: Layout.iconPointSize, weight: .medium)
        // "dice" needs SF Symbols 4; iOS 15 falls back to the bar item's die
        imageView.image = UIImage(systemName: "dice", withConfiguration: config)
            ?? UIImage(systemName: "die.face.5", withConfiguration: config)
        imageView.tintColor = .blue100
        imageView.contentMode = .center
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        label.font = ThemeManager.Fonts.titleFont(size: Layout.titleSize, weight: .semibold)
        label.textColor = .textPrimary
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.subtitle
        label.font = .systemFont(ofSize: Layout.subtitleSize, weight: .regular)
        label.textColor = .textSecondary
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let chevronIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: Layout.chevronPointSize, weight: .semibold)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.textSpacing
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Layout.spacing
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
                self.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }

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
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(iconView)
        contentStack.addArrangedSubview(textStack)
        contentStack.addArrangedSubview(chevronIcon)
        addSubview(contentStack)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = [Strings.title, Strings.subtitle].joined(separator: ", ")

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: Layout.height),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.sidePadding),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.sidePadding),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            contentStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
    }

    // MARK: - Actions

    @objc private func handleTap() {
        onTap?()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview(traits: .fixedLayout(width: 400, height: 120)) {
    let container = UIView()
    container.backgroundColor = .mainBackground
    let row = HomeLuckyRowView()
    row.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(row)
    NSLayoutConstraint.activate([
        row.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        row.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
        row.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}
#endif

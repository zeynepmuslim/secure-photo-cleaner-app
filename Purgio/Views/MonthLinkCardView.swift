//
//  MonthLinkCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

/// A month's row as on the months list (`MonthProgressRowView`) in a tappable card with a
/// chevron. The empty Delete Bin points back to a month with it.
final class MonthLinkCardView: UIControl {
    private enum Layout {
        static let chevronPointSize: CGFloat = 12
        static let chevronSize = CGSize(width: 10, height: 14)
        static let highlightedAlpha: CGFloat = 0.8
        static let highlightDuration: TimeInterval = 0.25
    }

    let rowView: MonthProgressRowView = {
        let view = MonthProgressRowView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        return view
    }()

    private let chevronView: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: Layout.chevronPointSize, weight: .semibold)
        let imageView = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: config))
        imageView.tintColor = .textTertiary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    var onTap: (() -> Void)?

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: Layout.highlightDuration) {
                self.alpha = self.isHighlighted ? Layout.highlightedAlpha : 1.0
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        addSubview(rowView)
        addSubview(chevronView)
        NSLayoutConstraint.activate([
            rowView.topAnchor.constraint(equalTo: topAnchor),
            rowView.leadingAnchor.constraint(equalTo: leadingAnchor),
            rowView.bottomAnchor.constraint(equalTo: bottomAnchor),
            rowView.trailingAnchor.constraint(equalTo: chevronView.leadingAnchor),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -GeneralConstants.EdgePadding.medium),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: Layout.chevronSize.width),
            chevronView.heightAnchor.constraint(equalToConstant: Layout.chevronSize.height)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        onTap?()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let card = MonthLinkCardView()
    card.rowView.configure(
        title: "August 2025", deleted: 6, kept: 12, stored: 3, total: 40, reviewed: 21,
        notStartedSubtitle: "40 photos to review")
    card.translatesAutoresizingMaskIntoConstraints = false

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(card)
    NSLayoutConstraint.activate([
        card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        card.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}
#endif

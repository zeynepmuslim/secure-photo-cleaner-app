//
//  SettingsLinkRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.04.2026.
//

import SwiftUI
import UIKit

final class SettingsLinkRowView: UIControl {

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let chevronView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    func configure(iconName: String, iconColor: UIColor, title: String) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconView.tintColor = iconColor
        titleLabel.text = title
    }

    private func setupViews() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.isUserInteractionEnabled = false

        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isUserInteractionEnabled = false

        let chevronConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        chevronView.image = UIImage(systemName: "chevron.right", withConfiguration: chevronConfig)
        chevronView.tintColor = .tertiaryLabel
        chevronView.contentMode = .scaleAspectFit
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.isUserInteractionEnabled = false

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(chevronView)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 54),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: chevronView.leadingAnchor, constant: -12),

            chevronView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            chevronView.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevronView.widthAnchor.constraint(equalToConstant: 14),
            chevronView.heightAnchor.constraint(equalToConstant: 14),
        ])

        addTarget(self, action: #selector(handleTap), for: .touchUpInside)
    }

    @objc private func handleTap() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        onTap?()
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.backgroundColor = self.isHighlighted
                    ? UIColor.label.withAlphaComponent(0.06)
                    : .clear
            }
        }
    }
}

@available(iOS 17.0, *)
private struct SettingsLinkRowPreview: UIViewRepresentable {
    let iconName: String
    let iconColor: UIColor
    let title: String
    let grouped: Bool

    func makeUIView(context: Context) -> UIView {
        let row = SettingsLinkRowView()
        row.configure(iconName: iconName, iconColor: iconColor, title: title)

        let host = UIView()
        host.backgroundColor = .cardBackground
        host.layer.cornerRadius = 14
        host.clipsToBounds = true
        host.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: host.topAnchor),
            row.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])

        if grouped {
            let secondRow = SettingsLinkRowView()
            secondRow.configure(
                iconName: "envelope.fill",
                iconColor: .systemBlue,
                title: "Give Feedback"
            )
            let separator = UIView()
            separator.backgroundColor = .separator
            separator.translatesAutoresizingMaskIntoConstraints = false

            let stack = UIStackView(arrangedSubviews: [row, separator, secondRow])
            stack.axis = .vertical
            stack.spacing = 0
            stack.translatesAutoresizingMaskIntoConstraints = false

            host.subviews.forEach { $0.removeFromSuperview() }
            host.addSubview(stack)

            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: host.topAnchor),
                stack.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                separator.heightAnchor.constraint(equalToConstant: 0.5),
            ])
        }

        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: UIView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? 350
        let fitting = uiView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitting.height)
    }
}

@available(iOS 17.0, *)
#Preview("Rate Row") {
    SettingsLinkRowPreview(
        iconName: "star.fill",
        iconColor: .systemYellow,
        title: "Rate the App",
        grouped: false
    )
    .frame(width: 350)
    .padding()
}

@available(iOS 17.0, *)
#Preview("Feedback Row") {
    SettingsLinkRowPreview(
        iconName: "envelope.fill",
        iconColor: .systemBlue,
        title: "Give Feedback",
        grouped: false
    )
    .frame(width: 350)
    .padding()
}

@available(iOS 17.0, *)
#Preview("Grouped (as used in Settings)") {
    SettingsLinkRowPreview(
        iconName: "star.fill",
        iconColor: .systemYellow,
        title: "Rate the App",
        grouped: true
    )
    .frame(width: 350)
    .padding()
}

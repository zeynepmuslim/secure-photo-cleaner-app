//
//  SettingsInfoCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.04.2026.
//

import SwiftUI
import UIKit

struct SettingsInfoCardConfig {
    let iconName: String
    let iconColor: UIColor
    let title: String
    let subtitle: String
    let themeColor: UIColor
    let buttonTitle: String?
    let buttonIconName: String?
    let buttonImageName: String?

    init(
        iconName: String,
        iconColor: UIColor,
        title: String,
        subtitle: String,
        themeColor: UIColor = .systemBlue,
        buttonTitle: String? = nil,
        buttonIconName: String? = nil,
        buttonImageName: String? = nil
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.subtitle = subtitle
        self.themeColor = themeColor
        self.buttonTitle = buttonTitle
        self.buttonIconName = buttonIconName
        self.buttonImageName = buttonImageName
    }
}

final class SettingsInfoCardView: UIView {

    var onButtonTapped: (() -> Void)?
    var onCardTapped: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let topStack = UIStackView()
    private let contentStack = UIStackView()
    private var actionButton: UIButton?
    private var config: SettingsInfoCardConfig?

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    init(config: SettingsInfoCardConfig) {
        self.config = config
        super.init(frame: .zero)
        setup(config: config)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func configure(with config: SettingsInfoCardConfig) {
        self.config = config
        setup(config: config)
    }

    func refreshButtonIcon() {
        guard let config = config, let imageName = config.buttonImageName else {
            return
        }
        actionButton?.configuration?.image = UIImage(named: imageName)?.resized(
            to: CGSize(width: 20, height: 20)
        )
    }

    private func setup(config: SettingsInfoCardConfig) {
        backgroundColor = .cardBackground
        layer.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false

        let symbolConfig = UIImage.SymbolConfiguration(
            pointSize: 20,
            weight: .medium
        )
        iconView.image = UIImage(
            systemName: config.iconName,
            withConfiguration: symbolConfig
        )
        iconView.tintColor = config.iconColor
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = config.title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label

        subtitleLabel.text = config.subtitle
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        topStack.axis = .horizontal
        topStack.spacing = 12
        topStack.alignment = .center
        topStack.translatesAutoresizingMaskIntoConstraints = false
        topStack.addArrangedSubview(iconView)
        topStack.addArrangedSubview(titleLabel)

        let hasButton = config.buttonTitle != nil
        contentStack.axis = .vertical
        contentStack.spacing = hasButton ? 12 : 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(topStack)
        contentStack.addArrangedSubview(subtitleLabel)

        if let buttonTitle = config.buttonTitle {
            let button = UIButton(type: .system)
            var buttonConfig = UIButton.Configuration.filled()
            buttonConfig.baseBackgroundColor = config.themeColor
                .withAlphaComponent(0.15)
            buttonConfig.baseForegroundColor = .label
            buttonConfig.title = buttonTitle
            buttonConfig.imagePadding = 8
            buttonConfig.cornerStyle = .medium
            buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)

            if let sfName = config.buttonIconName {
                buttonConfig.image = UIImage(systemName: sfName)
            } else if let imageName = config.buttonImageName {
                buttonConfig.image = UIImage(named: imageName)?.resized(
                    to: CGSize(width: 20, height: 20)
                )
            }

            button.configuration = buttonConfig
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(
                self,
                action: #selector(buttonTapped),
                for: .touchUpInside
            )

            contentStack.addArrangedSubview(button)
            actionButton = button
        }

        addSubview(contentStack)

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(cardTapped)
        )
        addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            contentStack.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            contentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    @objc private func buttonTapped() {
        onButtonTapped?()
    }

    @objc private func cardTapped() {
        onCardTapped?()
    }
}

@available(iOS 17.0, *)
private struct SettingsInfoCardPreview: UIViewRepresentable {
    let config: SettingsInfoCardConfig

    func makeUIView(context: Context) -> UIView {
        let card = SettingsInfoCardView(config: config)
        let host = UIView()
        host.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: host.topAnchor),
            card.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
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
            CGSize(
                width: width,
                height: UIView.layoutFittingCompressedSize.height
            ),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return CGSize(width: width, height: fitting.height)
    }
}

@available(iOS 17.0, *)
#Preview("Privacy Card") {
    SettingsInfoCardPreview(
        config: SettingsInfoCardConfig(
            iconName: "lock.shield",
            iconColor: .systemBlue,
            title: NSLocalizedString("settings.privacyTitle", comment: ""),
            subtitle: NSLocalizedString("settings.privacyText", comment: "")
        )
    )
    .frame(width: 350)
    .padding()
}

@available(iOS 17.0, *)
#Preview("Store Card") {
    SettingsInfoCardPreview(
        config: SettingsInfoCardConfig(
            iconName: "archivebox.fill",
            iconColor: .systemYellow,
            title: NSLocalizedString("settings.storeTitle", comment: ""),
            subtitle: NSLocalizedString("settings.storeText", comment: "")
        )
    )
    .frame(width: 350)
    .padding()
}

@available(iOS 17.0, *)
#Preview("Transparency Card") {
    SettingsInfoCardPreview(
        config: SettingsInfoCardConfig(
            iconName: "checkmark.shield.fill",
            iconColor: .systemGreen,
            title: NSLocalizedString("settings.transparencyTitle", comment: ""),
            subtitle: NSLocalizedString(
                "settings.transparencyText",
                comment: ""
            ),
            themeColor: .systemGreen,
            buttonTitle: NSLocalizedString(
                "settings.viewSourceCode",
                comment: ""
            ),
            buttonImageName: "GitHub_Invertocat"
        )
    )
    .frame(width: 350)
    .padding()
}

@available(iOS 17.0, *)
#Preview("Support Card") {
    SettingsInfoCardPreview(
        config: SettingsInfoCardConfig(
            iconName: "heart.fill",
            iconColor: .tipJarRed100,
            title: NSLocalizedString("settings.supportTitle", comment: ""),
            subtitle: NSLocalizedString("settings.supportText", comment: ""),
            themeColor: .tipJarRed100,
            buttonTitle: NSLocalizedString(
                "settings.supportButton",
                comment: ""
            ),
            buttonIconName: "sparkles"
        )
    )
    .frame(width: 350)
    .padding()
}

@available(iOS 17.0, *)
#Preview("Language Card") {
    SettingsInfoCardPreview(
        config: SettingsInfoCardConfig(
            iconName: "globe",
            iconColor: .systemBlue,
            title: NSLocalizedString("settings.languageTitle", comment: ""),
            subtitle: NSLocalizedString(
                "settings.languageSubtitle",
                comment: ""
            ),
            themeColor: .systemBlue,
            buttonTitle: NSLocalizedString(
                "settings.languageButton",
                comment: ""
            ),
            buttonIconName: "gear"
        )
    )
    .frame(width: 350)
    .padding()
}

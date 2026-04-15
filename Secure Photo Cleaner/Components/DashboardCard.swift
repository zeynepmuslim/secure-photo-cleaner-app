//
//  DashboardCard.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import UIKit

class DashboardCard: UIView {

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .label
        label.numberOfLines = 2
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .small
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let alignmentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .equalSpacing
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var buttonAction: (() -> Void)?
    private var currentContent: DashboardCardContent?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = 14
        layer.borderWidth = 0
        layer.borderColor = UIColor.separator.cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let isSmallScreen = UIScreen.main.bounds.width < 390

        let iconPointSize: CGFloat = isSmallScreen ? 20 : 24
        let iconConfig = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .medium)
        iconView.preferredSymbolConfiguration = iconConfig

        let titleSize: CGFloat = isSmallScreen ? 15 : 18
        titleLabel.font = ThemeManager.Fonts.titleFont(size: titleSize, weight: .semibold)

        headerStack.spacing = isSmallScreen ? 10 : 12

        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        headerStack.addArrangedSubview(iconView)
        headerStack.addArrangedSubview(titleLabel)

        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.addArrangedSubview(actionButton)

        alignmentStack.addArrangedSubview(UIView.flexibleSpacer())
        alignmentStack.addArrangedSubview(contentStack)
        alignmentStack.addArrangedSubview(UIView.flexibleSpacer())

        addSubview(alignmentStack)

        setupConstraint(isSmallScreen: isSmallScreen)
    }

    private func setupConstraint(isSmallScreen: Bool) {
        let iconDimension: CGFloat = isSmallScreen ? 24 : 28
        let horizontalPadding: CGFloat = isSmallScreen ? 14 : 18

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: iconDimension),
            iconView.heightAnchor.constraint(equalToConstant: iconDimension),

            alignmentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            alignmentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: horizontalPadding),
            alignmentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -horizontalPadding),
            alignmentStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            actionButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    func configure(with content: DashboardCardContent, actionHandler: @escaping (DashboardCardAction) -> Void) {
        currentContent = content

        iconView.image = UIImage(systemName: content.icon)
        iconView.tintColor = .blue100
        titleLabel.text = content.title
        subtitleLabel.text = content.subtitle
        actionButton.setTitle(content.action.buttonTitle, for: .normal)

        var config = actionButton.configuration
        config?.baseBackgroundColor = .blue100
        actionButton.configuration = config

        self.buttonAction = { [weak self] in
            guard let self = self, let content = self.currentContent else { return }
            actionHandler(content.action)
        }
    }
    
    func updateContent(_ content: DashboardCardContent, actionHandler: @escaping (DashboardCardAction) -> Void) {
        UIView.transition(with: self, duration: 0.3, options: .transitionCrossDissolve) {
            self.configure(with: content, actionHandler: actionHandler)
        }
    }

    @objc private func buttonTapped() {
        buttonAction?()
    }
}

// MARK: - Previews
#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct DashboardCardPreview: UIViewRepresentable {
        let configure: (DashboardCard) -> Void

        func makeUIView(context: Context) -> DashboardCard {
            let view = DashboardCard()
            configure(view)
            return view
        }

        func updateUIView(_ uiView: DashboardCard, context: Context) {
            configure(uiView)
        }

        func sizeThatFits(_ proposal: ProposedViewSize, uiView: DashboardCard, context: Context) -> CGSize? {
            return CGSize(width: proposal.width ?? 360, height: 190)
        }
    }

    @available(iOS 17.0, *)
    #Preview("Motivation Card", traits: .sizeThatFitsLayout) {
        DashboardCardPreview { view in
            let content = DashboardCardContent.motivation(
                title: NSLocalizedString("motivation.newMemories", comment: ""),
                subtitle: NSLocalizedString("suggestion.oldestFiles", comment: ""),
                action: .viewOldestYear(year: "2017")
            )
            view.configure(with: content) { _ in }
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Analytics Card", traits: .sizeThatFitsLayout) {
        DashboardCardPreview { view in
            let content = DashboardCardContent.analytics(
                title: NSLocalizedString("dashboard.yourImpact", comment: ""),
                subtitle: NSLocalizedString("analytics.itemsCleaned", comment: "")
            )
            view.configure(with: content) { _ in }
        }
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Resume Card", traits: .sizeThatFitsLayout) {
        DashboardCardPreview { view in
            let content = DashboardCardContent.motivation(
                title: NSLocalizedString("dashboard.continueWhereLeftOff", comment: ""),
                subtitle: NSLocalizedString("dashboard.continueMonth", comment: ""),
                action: .resumeMonth(monthKey: "2024-10", mediaType: .image)
            )
            view.configure(with: content) { _ in }
        }
        .padding()
    }

#endif

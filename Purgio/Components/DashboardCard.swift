//
//  DashboardCard.swift
//  Purgio
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

    private var iconWidthConstraint: NSLayoutConstraint?
    private var iconHeightConstraint: NSLayoutConstraint?
    private var leadingConstraint: NSLayoutConstraint?
    private var trailingConstraint: NSLayoutConstraint?

    private var bottomLeftCornerRadius: CGFloat?
    private let cornerMaskLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applySizeVariant()
        updateCornerMaskIfNeeded()
    }

    func setBottomLeftCornerRadius(_ radius: CGFloat?) {
        bottomLeftCornerRadius = radius

        guard radius != nil else {
            layer.mask = nil
            layer.cornerRadius = GeneralConstants.CornerRadius.card
            layer.masksToBounds = true
            return
        }

        layer.cornerRadius = 0
        updateCornerMaskIfNeeded()
    }

    private func updateCornerMaskIfNeeded() {
        guard let bottomLeftCornerRadius, bounds.width > 0, bounds.height > 0 else { return }
        let defaultRadius = GeneralConstants.CornerRadius.card
        cornerMaskLayer.frame = bounds
        cornerMaskLayer.path = Self.roundedCornersPath(
            in: bounds,
            topLeft: defaultRadius,
            topRight: defaultRadius,
            bottomLeft: bottomLeftCornerRadius,
            bottomRight: defaultRadius
        ).cgPath
        layer.mask = cornerMaskLayer
    }

    private static func roundedCornersPath(
        in rect: CGRect, topLeft: CGFloat, topRight: CGFloat, bottomLeft: CGFloat, bottomRight: CGFloat
    ) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
            radius: topRight, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(
            withCenter: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
            radius: bottomRight, startAngle: 0, endAngle: .pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(
            withCenter: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
            radius: bottomLeft, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(
            withCenter: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
            radius: topLeft, startAngle: .pi, endAngle: .pi * 3 / 2, clockwise: true)
        path.close()
        return path
    }

    private func applySizeVariant() {
        let isSmallScreen = (window?.bounds.width ?? bounds.width) < 390

        let iconPointSize: CGFloat = isSmallScreen ? 20 : 24
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: iconPointSize, weight: .medium)

        let titleSize: CGFloat = isSmallScreen ? 15 : 18
        titleLabel.font = ThemeManager.Fonts.titleFont(size: titleSize, weight: .semibold)

        headerStack.spacing = isSmallScreen ? 10 : 12

        let iconDimension: CGFloat = isSmallScreen ? 24 : 28
        iconWidthConstraint?.constant = iconDimension
        iconHeightConstraint?.constant = iconDimension

        let horizontalPadding: CGFloat = isSmallScreen ? 14 : 18
        leadingConstraint?.constant = horizontalPadding
        trailingConstraint?.constant = -horizontalPadding
    }
    
    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 0
        layer.borderColor = UIColor.separator.cgColor
        translatesAutoresizingMaskIntoConstraints = false

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

        setupConstraint()
        applySizeVariant()
    }

    private func setupConstraint() {
        let iconWidthConstraint = iconView.widthAnchor.constraint(equalToConstant: 28)
        let iconHeightConstraint = iconView.heightAnchor.constraint(equalToConstant: 28)
        let leadingConstraint = alignmentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18)
        let trailingConstraint = alignmentStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18)
        self.iconWidthConstraint = iconWidthConstraint
        self.iconHeightConstraint = iconHeightConstraint
        self.leadingConstraint = leadingConstraint
        self.trailingConstraint = trailingConstraint

        NSLayoutConstraint.activate([
            iconWidthConstraint,
            iconHeightConstraint,

            alignmentStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            leadingConstraint,
            trailingConstraint,
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

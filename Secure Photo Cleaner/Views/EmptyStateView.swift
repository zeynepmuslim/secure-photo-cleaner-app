//
//  EmptyStateView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import UIKit

final class EmptyStateView: UIView {
    
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var actionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.cornerStyle = .capsule
        config.buttonSize = .medium

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleActionTap), for: .touchUpInside)
        return button
    }()

    private lazy var secondaryButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.cornerStyle = .capsule
        config.buttonSize = .medium

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleSecondaryTap), for: .touchUpInside)
        return button
    }()
    
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private var onAction: (() -> Void)?
    private var onSecondaryAction: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -40)
        ])
        
        alpha = 0
    }
    
    func configure(
        icon: String? = nil,
        iconColor: UIColor = .systemGray,
        title: String,
        message: String,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        secondaryActionTitle: String? = nil,
        onSecondaryAction: (() -> Void)? = nil
    ) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if let icon = icon {
            iconImageView.image = UIImage(systemName: icon)
            iconImageView.tintColor = iconColor
            stackView.addArrangedSubview(iconImageView)

            NSLayoutConstraint.activate([
                iconImageView.widthAnchor.constraint(equalToConstant: 60),
                iconImageView.heightAnchor.constraint(equalToConstant: 60)
            ])

            stackView.setCustomSpacing(24, after: iconImageView)
        }

        titleLabel.text = title
        stackView.addArrangedSubview(titleLabel)
        stackView.setCustomSpacing(8, after: titleLabel)

        messageLabel.text = message
        stackView.addArrangedSubview(messageLabel)

        if let actionTitle = actionTitle, onAction != nil {
            var config = actionButton.configuration ?? UIButton.Configuration.filled()
            config.title = actionTitle
            actionButton.configuration = config

            self.onAction = onAction

            stackView.setCustomSpacing(24, after: messageLabel)
            stackView.addArrangedSubview(actionButton)
        }

        if let secondaryTitle = secondaryActionTitle, onSecondaryAction != nil {
            var config = secondaryButton.configuration ?? UIButton.Configuration.tinted()
            config.title = secondaryTitle
            secondaryButton.configuration = config

            self.onSecondaryAction = onSecondaryAction

            stackView.setCustomSpacing(12, after: actionButton)
            stackView.addArrangedSubview(secondaryButton)
        }
    }
    
    @objc private func handleActionTap() {
        onAction?()
    }

    @objc private func handleSecondaryTap() {
        onSecondaryAction?()
    }
    
    func show(animated: Bool = true) {
        guard animated else {
            alpha = 1
            return
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
        }
    }
    
    func hide(animated: Bool = true) {
        guard animated else {
            alpha = 0
            return
        }

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.alpha = 0
        } completion: { _ in
            self.removeFromSuperview()
        }
    }
}

// MARK: - Previews

#if DEBUG

@available(iOS 17.0, *)
#Preview("Icon + Title + Message") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        icon: "photo.on.rectangle.angled",
        title: NSLocalizedString("monthReview.noResultsTitle", comment: ""),
        message: NSLocalizedString("monthReview.noResultsMessage", comment: "")
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Icon + Title + Message + Action") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        icon: "trash.slash",
        title: NSLocalizedString("deleteBin.emptyMessage", comment: ""),
        message: NSLocalizedString("deleteBin.yourDeleteBin", comment: ""),
        actionTitle: NSLocalizedString("dashboard.getStarted", comment: ""),
        onAction: {}
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Icon + Title + Message + Both Buttons") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        icon: "exclamationmark.triangle",
        title: "Access Denied",
        message: "Please grant photo library access to use this feature.",
        actionTitle: "Open Settings",
        onAction: {},
        secondaryActionTitle: "Learn More",
        onSecondaryAction: {}
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

@available(iOS 17.0, *)
#Preview("Title + Message Only") {
    let vc = UIViewController()
    let emptyState = EmptyStateView(frame: vc.view.bounds)
    emptyState.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    emptyState.configure(
        title: NSLocalizedString("similarPhotos.noSimilarTitle", comment: ""),
        message: NSLocalizedString("similarPhotos.noSimilarMessage", comment: "")
    )
    emptyState.show(animated: false)
    vc.view.addSubview(emptyState)
    return vc
}

#endif

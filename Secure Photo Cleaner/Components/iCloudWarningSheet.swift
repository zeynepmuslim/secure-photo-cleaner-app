//
//  iCloudWarningType.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import UIKit

enum MediaType {
    case photo
    case video

    var displayName: String {
        switch self {
        case .photo: return NSLocalizedString("mediaType.photo", comment: "Photo media type name")
        case .video: return NSLocalizedString("mediaType.video", comment: "Video media type name")
        }
    }
}

enum iCloudWarningType {
    case initial   // Shown when entering review with iCloud-only content offline
    case perCard(MediaType)   // Shown when content can't be displayed at all

    var title: String {
        switch self {
        case .initial:
            return NSLocalizedString("iCloudWarning.viewingLowQuality", comment: "Viewing in low quality title")
        case .perCard(let mediaType):
            return String(format: NSLocalizedString("iCloudWarning.mediaUnavailable", comment: "Media unavailable title, e.g. 'Photo Unavailable'"), mediaType.displayName)
        }
    }

    var message: String {
        switch self {
        case .initial:
            return NSLocalizedString("iCloudWarning.lowQualityMessage", comment: "Low quality iCloud content message")
        case .perCard(let mediaType):
            switch mediaType {
            case .video:
                return NSLocalizedString("iCloudWarning.videoUnavailableMessage", comment: "Video unavailable iCloud message")
            case .photo:
                return NSLocalizedString("iCloudWarning.photoUnavailableMessage", comment: "Photo unavailable iCloud message")
            }
        }
    }
}


final class iCloudWarningSheet: UIViewController {

    var onEnableInternet: (() -> Void)?
    var onSkipThisOne: (() -> Void)?
    var onContinueOffline: (() -> Void)?

    private let warningType: iCloudWarningType

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let iconStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalSpacing
        return stack
    }()

    private let labelStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    private let buttonsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        return stack
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        return label
    }()

    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var enableInternetButton: DynamicGlassButton = {
        createActionButton(
            title: "Enable Internet Access",
            icon: "network",
            color: .systemBlue,
            isPrimary: true
        )
    }()

    private lazy var skipThisOneButton: DynamicGlassButton = {
        createActionButton(
            title: "Skip This One",
            icon: "chevron.right.2",
            color: .systemGray,
            isPrimary: false
        )
    }()

    private lazy var continueOfflineButton: DynamicGlassButton = {
        createActionButton(
            title: "Continue with Preview",
            icon: "chevron.right",
            color: .systemGray,
            isPrimary: false
        )
    }()

    init(type: iCloudWarningType) {
        self.warningType = type
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .pageSheet

        if let sheet = sheetPresentationController {
            switch type {
            case .initial:
                sheet.detents = [.medium()]
            case .perCard:
                if #available(iOS 16.0, *) {
                    sheet.detents = [.custom { _ in 380 }]
                } else {
                    sheet.detents = [.medium()]
                }
            }
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            sheet.prefersEdgeAttachedInCompactHeight = true
            sheet.widthFollowsPreferredContentSizeWhenEdgeAttached = true
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        configure()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // Build icon stack with spacers to center icon vertically
        iconStack.addArrangedSubview(UIView.flexibleSpacer())
        iconStack.addArrangedSubview(iconImageView)
        iconStack.addArrangedSubview(UIView.flexibleSpacer())

        // Build label stack
        labelStack.addArrangedSubview(titleLabel)
        labelStack.addArrangedSubview(messageLabel)

        // Add buttons based on warning type
        buttonsStack.addArrangedSubview(enableInternetButton)

        switch warningType {
        case .initial:
            buttonsStack.addArrangedSubview(continueOfflineButton)
        case .perCard:
            buttonsStack.addArrangedSubview(skipThisOneButton)
        }

        // Build main content hierarchy with equal spacing
        contentStack.addArrangedSubview(UIView.flexibleSpacer())
        contentStack.addArrangedSubview(iconStack)
        contentStack.addArrangedSubview(labelStack)
        contentStack.addArrangedSubview(buttonsStack)

        view.addSubview(contentStack)

        // Add targets
        enableInternetButton.addTarget(self, action: #selector(handleEnableInternet), for: .touchUpInside)
        skipThisOneButton.addTarget(self, action: #selector(handleSkipThisOne), for: .touchUpInside)
        continueOfflineButton.addTarget(self, action: #selector(handleContinueOffline), for: .touchUpInside)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),

            iconImageView.widthAnchor.constraint(equalToConstant: 60),
            iconImageView.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func configure() {
        titleLabel.text = warningType.title
        messageLabel.text = warningType.message

        // Configure icon based on warning type
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        switch warningType {
        case .initial:
            iconImageView.image = UIImage(systemName: "icloud.and.arrow.down", withConfiguration: iconConfig)
            iconImageView.tintColor = .systemBlue
        case .perCard:
            iconImageView.image = UIImage(systemName: "exclamationmark.icloud", withConfiguration: iconConfig)
            iconImageView.tintColor = .systemOrange
            skipThisOneButton.configure(
                title: "Skip",
                systemImage: "chevron.right.2",
                style: .regular,
                backgroundColor: .secondarySystemFill,
                foregroundColor: .systemGray,
                contentInsets: NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
            )
        }
    }

    // MARK: - Button Factory

    private func createActionButton(title: String, icon: String, color: UIColor, isPrimary: Bool) -> DynamicGlassButton {
        let button = DynamicGlassButton()
        button.configure(
            title: title,
            systemImage: icon,
            style: isPrimary ? .prominent : .regular,
            backgroundColor: isPrimary ? color : .secondarySystemFill,
            foregroundColor: isPrimary ? .white : color,
            contentInsets: NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        )
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }

    // MARK: - Actions

    @objc private func handleEnableInternet() {
        dismiss(animated: true) { [weak self] in
            self?.onEnableInternet?()
        }
    }

    @objc private func handleSkipThisOne() {
        dismiss(animated: true) { [weak self] in
            self?.onSkipThisOne?()
        }
    }

    @objc private func handleContinueOffline() {
        dismiss(animated: true) { [weak self] in
            self?.onContinueOffline?()
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Initial Warning") {
        iCloudWarningSheet(type: .initial)
    }

    @available(iOS 17.0, *)
    #Preview("Per Card Warning - Photo") {
        iCloudWarningSheet(type: .perCard(.photo))
    }

    @available(iOS 17.0, *)
    #Preview("Per Card Warning - Video") {
        iCloudWarningSheet(type: .perCard(.video))
    }
#endif

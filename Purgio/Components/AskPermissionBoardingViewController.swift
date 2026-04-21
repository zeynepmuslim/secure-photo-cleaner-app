//
//  AskPermissionBoardingViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 5.04.2026.
//

import Photos
import UIKit

private enum Strings {
    static let title = NSLocalizedString("askPermission.title", comment: "Ask permission screen title")
    static let subtitle = NSLocalizedString("askPermission.subtitle", comment: "Ask permission screen subtitle")
    static let allowAccess = NSLocalizedString("monthsList.allowPhotoAccess", comment: "Allow photo access button title")
    static let settingsAlertTitle = NSLocalizedString("askPermission.settingsAlertTitle", comment: "Alert title when photo access is denied")
    static let settingsAlertMessage = NSLocalizedString("askPermission.settingsAlertMessage", comment: "Alert message when photo access is denied")
    static let openSettings = NSLocalizedString("askPermission.openSettings", comment: "Open Settings action")
    static let privacyNoAccount = NSLocalizedString("askPermission.privacyNoAccount", comment: "Privacy row: no account or sign-up")
    static let privacyOnDevice = NSLocalizedString("askPermission.privacyOnDevice", comment: "Privacy row: photos analyzed on-device")
    static let privacyNoInternet = NSLocalizedString("askPermission.privacyNoInternet", comment: "Privacy row: no internet connection needed")
}

final class AskPermissionBoardingViewController: UIViewController {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.subtitle
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let bubbleView: SoapBubble = {
        let bubble = SoapBubble()
        bubble.autoStartsAnimating = false
        bubble.iridescenceColors = [
            UIColor(red: 0.60, green: 0.92, blue: 0.78, alpha: 1).cgColor, // mint
            UIColor(red: 0.40, green: 0.85, blue: 0.60, alpha: 1).cgColor, // fresh green
            UIColor(red: 0.70, green: 0.95, blue: 0.55, alpha: 1).cgColor, // lime
            UIColor(red: 0.50, green: 0.90, blue: 0.85, alpha: 1).cgColor, // sea-green
            UIColor(red: 0.75, green: 0.92, blue: 0.70, alpha: 1).cgColor, // sage
            UIColor(red: 0.60, green: 0.92, blue: 0.78, alpha: 1).cgColor, // mint
        ]
        bubble.translatesAutoresizingMaskIntoConstraints = false
        return bubble
    }()

    private let privacyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let allowButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var hasAnimated = false
    private var photoOverlay: UIView?

    private let isSmallScreen = UIScreen.main.bounds.height < 700

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !hasAnimated {
            bubbleView.transform = CGAffineTransform(scaleX: 0.001, y: 0.001)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAnimated else { return }
        hasAnimated = true

        bubbleView.startAnimating()
        UIView.animate(
            withDuration: 0.45,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.5,
            options: .curveEaseOut
        ) {
            self.bubbleView.transform = .identity
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupUI() {
        view.backgroundColor = .mainBackground

        allowButton.configure(
            title: Strings.allowAccess,
            style: .prominent,
            backgroundColor: UIColor(named: "AccentColor") ?? .systemGreen,
            foregroundColor: .white,
            contentInsets: NSDirectionalEdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
        )
        allowButton.addTarget(self, action: #selector(allowTapped), for: .touchUpInside)

        bubbleView.onPhotoTapped = { [weak self] image in
            self?.showPhotoOverlay(image)
        }

        let privacyItems: [(symbol: String, text: String)] = [
            ("person.crop.circle.badge.xmark", Strings.privacyNoAccount),
            ("cpu", Strings.privacyOnDevice),
            ("wifi.slash", Strings.privacyNoInternet)
        ]
        
        privacyItems.forEach { item in
            privacyStack.addArrangedSubview(makePrivacyRow(symbol: item.symbol, text: item.text))
        }

        view.addSubview(contentStack)
        view.addSubview(allowButton)

        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subtitleLabel)

        contentStack.addArrangedSubview(UIView.flexibleSpacer())
        contentStack.addArrangedSubview(headerStack)
        contentStack.addArrangedSubview(bubbleView)
        contentStack.addArrangedSubview(privacyStack)
    }

    private func makePrivacyRow(symbol: String, text: String) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let icon = UIImageView(image: UIImage(systemName: symbol, withConfiguration: config))
        icon.tintColor = .textSecondary
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true

        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .textSecondary
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        row.addArrangedSubview(icon)
        row.addArrangedSubview(label)
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    private func setupConstraint() {
        let screenWidth = UIScreen.main.bounds.width
        let isVeryNarrow = screenWidth < 370 // iPhone 7
        let ballDiameter: CGFloat
        if isVeryNarrow {
            ballDiameter = 200
        } else if isSmallScreen {
            ballDiameter = 240
        } else {
            ballDiameter = 280
        }
        let horizontalPadding: CGFloat = 28

        let bubbleHeight = bubbleView.heightAnchor.constraint(equalToConstant: ballDiameter)
        bubbleHeight.priority = .defaultHigh

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalPadding),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalPadding),
            contentStack.bottomAnchor.constraint(equalTo: allowButton.topAnchor, constant: -16),

            bubbleView.widthAnchor.constraint(equalTo: bubbleView.heightAnchor),
            bubbleView.widthAnchor.constraint(lessThanOrEqualToConstant: ballDiameter),
            bubbleHeight,

            allowButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: horizontalPadding),
            allowButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -horizontalPadding),
            allowButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            privacyStack.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            privacyStack.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor),
        ])

    }

    @objc private func allowTapped() {
        allowButton.isEnabled = false
        Task { @MainActor in
            let status = await PhotoLibraryService.shared.requestAuthorization()

            self.allowButton.isEnabled = true

            if status == .authorized || status == .limited {
                self.dismiss(animated: true)
            } else {
                self.showSettingsAlert()
            }
        }
    }

    private func showSettingsAlert() {
        let alert = UIAlertController(
            title: Strings.settingsAlertTitle,
            message: Strings.settingsAlertMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.openSettings, style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        })
        present(alert, animated: true)
    }

    @objc private func appDidBecomeActive() {
        let status = PhotoLibraryService.shared.authorizationStatus()
        if status == .authorized || status == .limited {
            dismiss(animated: true)
        }
    }

    private func showPhotoOverlay(_ image: UIImage) {
        guard photoOverlay == nil else { return }

        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        container.alpha = 0
        view.addSubview(container)

        let imageView = UIImageView(image: image)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 28
        imageView.clipsToBounds = true
        imageView.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        container.addSubview(imageView)

        let closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(
            UIImage(
                systemName: "xmark.circle.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)
            ),
            for: .normal
        )
        closeButton.tintColor = .white
        closeButton.addTarget(self, action: #selector(dismissPhotoOverlay), for: .touchUpInside)
        container.addSubview(closeButton)

        let preferredWidth = imageView.widthAnchor.constraint(equalTo: container.widthAnchor, constant: -80)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            imageView.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -80),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            imageView.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            imageView.topAnchor.constraint(greaterThanOrEqualTo: container.safeAreaLayoutGuide.topAnchor, constant: 80),
            imageView.bottomAnchor.constraint(lessThanOrEqualTo: container.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            preferredWidth,

            closeButton.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissPhotoOverlay))
        container.addGestureRecognizer(tap)

        photoOverlay = container

        UIView.animate(
            withDuration: 0.3,
            delay: 0,
            usingSpringWithDamping: 0.75,
            initialSpringVelocity: 0.3,
            options: .curveEaseOut
        ) {
            container.alpha = 1
            imageView.transform = .identity
        }
    }

    @objc private func dismissPhotoOverlay() {
        guard let overlay = photoOverlay else { return }
        photoOverlay = nil
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseIn,
            animations: {
                overlay.alpha = 0
            }
        ) { _ in
            overlay.removeFromSuperview()
        }
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Light Mode") {
        let vc = AskPermissionBoardingViewController()
        vc.overrideUserInterfaceStyle = .light
        return vc
    }

    @available(iOS 17.0, *)
    #Preview("Dark Mode") {
        let vc = AskPermissionBoardingViewController()
        vc.overrideUserInterfaceStyle = .dark
        return vc
    }
#endif

//
//  TipJarViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.04.2026.
//

import Combine
import StoreKit
import UIKit

private enum Strings {
    static let title = NSLocalizedString("tipJar.title", comment: "Tip jar sheet title")
    static let openSourceNote = NSLocalizedString("tipJar.openSourceNote", comment: "Tip jar open source / free explanation")
    static let thankYou = NSLocalizedString("tipJar.thankYou", comment: "Thank you message after successful tip")
    static let error = NSLocalizedString("tipJar.error", comment: "Generic tip jar error")
    static let retry = NSLocalizedString("tipJar.retry", comment: "Retry loading products button")
    static let selectAmount = NSLocalizedString("tipJar.selectAmount", comment: "Button placeholder when no tip is selected")
    static let sendTipFormat = NSLocalizedString("tipJar.sendTipFormat", comment: "Button when a tip is selected; %@ is the price")
    static let tierSmall = NSLocalizedString("tipJar.tier.small", comment: "Small tip card label")
    static let tierMedium = NSLocalizedString("tipJar.tier.medium", comment: "Medium tip card label")
    static let tierLarge = NSLocalizedString("tipJar.tier.large", comment: "Large tip card label")
    static let gateTitle = NSLocalizedString("tipJar.gate.title", comment: "Internet gate title in tip jar")
    static let gateSubtitle = NSLocalizedString("tipJar.gate.subtitle", comment: "Internet gate explanation in tip jar")
    static let gateEnableButton = NSLocalizedString("tipJar.gate.enableButton", comment: "Button to enable internet access from tip jar")
}

private enum Device {
    static var isCompactHeight: Bool {
        UIScreen.main.bounds.height <= 667
    }
    
    static var isRegularCompactHeight: Bool {
        UIScreen.main.bounds.height <= 812
    }
}

final class TipJarViewController: UIViewController {

    private let manager = TipJarManager.shared
    private var cancellables = Set<AnyCancellable>()

    private lazy var tierMetas: [(title: String, symbol: String, symbolSize: CGFloat)] = {
        let sizes: (CGFloat, CGFloat, CGFloat)
        if Device.isCompactHeight {
            sizes = (20, 24, 28)
        } else if Device.isRegularCompactHeight {
            sizes = (16, 20, 20)
        } else {
            sizes = (20, 24, 24)
        }
        return [
            (Strings.tierSmall, "sparkle", sizes.0),
            (Strings.tierMedium, "sparkles", sizes.1),
            (Strings.tierLarge, "wand.and.stars", sizes.2)
        ]
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let heroIconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 62, weight: .semibold)
        imageView.image = UIImage(systemName: "heart.fill", withConfiguration: config)
        imageView.tintColor = .tipJarRed100
        imageView.contentMode = .center
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.boldTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 1
        label.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return label
    }()

    private let openSourceNoteLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.heightAnchor.constraint(equalToConstant: 36).isActive = true
        return label
    }()

    private let cardsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fillEqually
        stack.spacing = 12
        return stack
    }()

    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    private lazy var retryButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = Strings.retry
        config.baseForegroundColor = .tipJarRed100
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .vertical)
        button.addAction(UIAction { [weak self] _ in
            self?.loadProducts()
        }, for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private let successContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()

    private let successIconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 72, weight: .semibold)
        imageView.image = UIImage(systemName: "heart.circle.fill", withConfiguration: config)
        imageView.tintColor = .tipJarRed100
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let successLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.boldTitle
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private var tipCards: [TipTier] = []
    private var selectedProduct: Product?
    private var didEnableInternetForSession = false
    private var pendingInternetRestoreFeedback = false

    var onRestoredInternet: (() -> Void)?

    private lazy var actionButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: Strings.selectAmount,
            backgroundColor: .tipJarRed100,
            font: ThemeManager.Fonts.semiboldBody,
            contentInsets: NSDirectionalEdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24)
        )
        button.heightAnchor.constraint(equalToConstant: 56).isActive = true
        button.isEnabled = false
        button.addAction(UIAction { [weak self] _ in
            self?.ctaButtonTapped()
        }, for: .touchUpInside)
        return button
    }()

    // MARK: - Internet Gate
    private let gateContainer: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 16
        stack.isHidden = true
        return stack
    }()

    private let gateIconView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .semibold)
        imageView.image = UIImage(systemName: "wifi.slash", withConfiguration: config)
        imageView.tintColor = .tipJarRed100
        imageView.contentMode = .center
        imageView.heightAnchor.constraint(equalToConstant: 60).isActive = true
        return imageView
    }()

    private let gateTitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.semiboldBody
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let gateSubtitleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()

    private lazy var gateEnableButton: SlideToConfirmButton = {
        let button = SlideToConfirmButton()
        button.title = Strings.gateEnableButton
        button.addAction(UIAction { [weak self] _ in
            self?.gateEnableButtonTapped()
        }, for: .primaryActionTriggered)
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    #if DEBUG
    enum PreviewState {
        case normal
        case gate
        case success
        case failed
    }

    private var _previewState: PreviewState?

    convenience init(previewState: PreviewState) {
        self.init()
        self._previewState = previewState
    }

    private func applyPreviewStateIfNeeded() {
        guard let state = _previewState else { return }
        switch state {
        case .normal:
            showNormalContent()
        case .gate:
            showInternetGate()
        case .success:
            heroIconView.isHidden = true
            titleLabel.isHidden = true
            openSourceNoteLabel.isHidden = true
            cardsStack.isHidden = true
            retryButton.isHidden = true
            actionButton.isHidden = true
            gateContainer.isHidden = true
            successContainer.isHidden = false
            successContainer.alpha = 1
        case .failed:
            showNormalContent()
            DispatchQueue.main.async { [weak self] in
                self?.showError("Transaction could not be completed. Please try again.")
            }
        }
    }
    #endif

    deinit {
        Task { @MainActor in
            TipJarManager.shared.resetPurchaseState()
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        if #available(iOS 26.0, *) {
            view.backgroundColor = .clear
        } else {
            view.backgroundColor = .mainBackground
        }
        configureSheet()
        setupUI()
        bindManager()

        if SettingsStore.shared.allowInternetAccess {
            showNormalContent()
            loadProducts()
        } else {
            showInternetGate()
        }

        #if DEBUG
        applyPreviewStateIfNeeded()
        #endif
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isBeingDismissed, didEnableInternetForSession else { return }
        SettingsStore.shared.allowInternetAccess = false
        didEnableInternetForSession = false
        pendingInternetRestoreFeedback = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard pendingInternetRestoreFeedback else { return }
        pendingInternetRestoreFeedback = false
        onRestoredInternet?()
    }

    private func configureSheet() {
        guard let sheet = sheetPresentationController else { return }
        sheet.detents = Device.isCompactHeight ? [.large()] : [.medium()]
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = false
    }

    // MARK: - UI
    private func setupUI() {
        titleLabel.text = Strings.title
        openSourceNoteLabel.text = Strings.openSourceNote
        successLabel.text = Strings.thankYou
        gateTitleLabel.text = Strings.gateTitle
        gateSubtitleLabel.text = Strings.gateSubtitle

        let successTopSpacer = UIView()
        let successBottomSpacer = UIView()
        successTopSpacer.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
        successBottomSpacer.setContentHuggingPriority(.defaultLow - 1, for: .vertical)

        successContainer.addArrangedSubview(successTopSpacer)
        successContainer.addArrangedSubview(successIconView)
        successContainer.addArrangedSubview(successLabel)
        successContainer.addArrangedSubview(successBottomSpacer)
        successContainer.setCustomSpacing(0, after: successTopSpacer)
        successContainer.setCustomSpacing(0, after: successLabel)
        
        successTopSpacer.heightAnchor.constraint(equalTo: successBottomSpacer.heightAnchor).isActive = true

        gateContainer.addArrangedSubview(gateIconView)
        gateContainer.setCustomSpacing(12, after: gateIconView)
        gateContainer.addArrangedSubview(gateTitleLabel)
        gateContainer.setCustomSpacing(8, after: gateTitleLabel)
        gateContainer.addArrangedSubview(gateSubtitleLabel)
        gateContainer.setCustomSpacing(24, after: gateSubtitleLabel)
        gateContainer.addArrangedSubview(gateEnableButton)

        contentStack.addArrangedSubview(heroIconView)
        contentStack.setCustomSpacing(12, after: heroIconView)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(8, after: titleLabel)
        contentStack.addArrangedSubview(openSourceNoteLabel)
        contentStack.setCustomSpacing(24, after: openSourceNoteLabel)
        contentStack.addArrangedSubview(cardsStack)
        contentStack.addArrangedSubview(retryButton)
        contentStack.addArrangedSubview(successContainer)
        contentStack.addArrangedSubview(gateContainer)
        contentStack.setCustomSpacing(24, after: cardsStack)
        contentStack.addArrangedSubview(actionButton)

        view.addSubview(contentStack)
        view.addSubview(loadingIndicator)

        if Device.isCompactHeight {
            cardsStack.heightAnchor.constraint(equalToConstant: 160).isActive = true
            heroIconView.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
            heroIconView.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
            heroIconView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        } else {
            heroIconView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        }

        let bottomInset: CGFloat = Device.isCompactHeight ? -24 : 0

        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: bottomInset),

            loadingIndicator.centerXAnchor.constraint(equalTo: cardsStack.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: cardsStack.centerYAnchor)
        ])
    }
    
    private func bindManager() {
        manager.$products
            .receive(on: DispatchQueue.main)   // Hop to main thread
            .sink { [weak self] products in    // Run each new value
                self?.rebuildCards(for: products)
            }
            .store(in: &cancellables)          // auto cancel on deinit

        manager.$purchaseState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handlePurchaseState(state)
            }
            .store(in: &cancellables)
    }

    private func loadProducts() {
        retryButton.isHidden = true
        loadingIndicator.startAnimating()
        Task { @MainActor in
            await manager.loadProducts()
            loadingIndicator.stopAnimating()
            if manager.products.isEmpty {
                retryButton.isHidden = false
            }
        }
    }

    // MARK: - Internet Gate
    private func showInternetGate() {
        gateContainer.isHidden = false
        cardsStack.isHidden = true
        retryButton.isHidden = true
        actionButton.isHidden = true
        successContainer.isHidden = true
    }

    private func showNormalContent() {
        gateContainer.isHidden = true
        cardsStack.isHidden = false
        actionButton.isHidden = false
        successContainer.isHidden = true
    }

    private func gateEnableButtonTapped() {
        SettingsStore.shared.allowInternetAccess = true
        didEnableInternetForSession = true
        HapticFeedbackManager.shared.impact(intensity: .medium)

        UIView.animate(withDuration: 0.2, animations: {
            self.gateContainer.alpha = 0
        }, completion: { _ in
            self.gateContainer.isHidden = true
            self.gateContainer.alpha = 1
            self.cardsStack.isHidden = false
            self.cardsStack.alpha = 0
            self.actionButton.isHidden = false
            self.actionButton.alpha = 0
            self.successContainer.isHidden = true
            self.view.layoutIfNeeded()

            UIView.animate(withDuration: 0.25) {
                self.cardsStack.alpha = 1
                self.actionButton.alpha = 1
            }
        })

        loadProducts()
    }

    // MARK: - Cards
    private func rebuildCards(for products: [Product]) {
        tipCards.forEach { $0.removeFromSuperview() }
        tipCards.removeAll()
        selectedProduct = nil
        updateActionButtonState()

        for (index, product) in products.enumerated() {
            let meta = index < tierMetas.count
                ? tierMetas[index]
                : (title: product.displayName, symbol: "heart.fill", symbolSize: CGFloat(32))
            let card = TipTier(
                title: meta.title,
                symbol: meta.symbol,
                symbolSize: meta.symbolSize,
                price: product.displayPrice
            )
            card.addAction(UIAction { [weak self] _ in
                self?.tipCardTapped(product: product)
            }, for: .touchUpInside)
            cardsStack.addArrangedSubview(card)
            tipCards.append(card)
        }
    }

    private func tipCardTapped(product: Product) {
        HapticFeedbackManager.shared.selection()
        selectedProduct = product
        let selectedIndex = manager.products.firstIndex(where: { $0.id == product.id })
        for (cardIndex, card) in tipCards.enumerated() {
            card.setSelected(cardIndex == selectedIndex)
        }
        updateActionButtonState()
    }

    private func ctaButtonTapped() {
        guard let product = selectedProduct else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        Task { @MainActor in
            await manager.purchase(product)
        }
    }

    private func updateActionButtonState() {
        if let product = selectedProduct {
            actionButton.title = String(format: Strings.sendTipFormat, product.displayPrice)
            actionButton.isEnabled = true
        } else {
            actionButton.title = Strings.selectAmount
            actionButton.isEnabled = false
        }
    }

    // MARK: - State Handling
    private func handlePurchaseState(_ state: TipJarManager.PurchaseState) {
        switch state {
        case .idle:
            setCardsEnabled(true)
            loadingIndicator.stopAnimating()

        case .purchasing:
            setCardsEnabled(false)
            loadingIndicator.startAnimating()

        case .success:
            loadingIndicator.stopAnimating()
            HapticFeedbackManager.shared.success()
            showSuccess()

        case .failed(let message):
            loadingIndicator.stopAnimating()
            setCardsEnabled(true)
            HapticFeedbackManager.shared.error()
            showError(message)
        }
    }

    private func setCardsEnabled(_ enabled: Bool) {
        tipCards.forEach { $0.isEnabled = enabled }
        retryButton.isEnabled = enabled
        actionButton.isEnabled = enabled && selectedProduct != nil
    }

    private func showSuccess() {
        let fadingOut: [UIView] = [
            heroIconView, titleLabel, openSourceNoteLabel,
            cardsStack, retryButton, actionButton, gateContainer
        ]

        UIView.animate(withDuration: 0.2, animations: {
            fadingOut.forEach { $0.alpha = 0 }
        }, completion: { _ in
            fadingOut.forEach {
                $0.isHidden = true
                $0.alpha = 1
            }
            self.successContainer.isHidden = false
            self.successContainer.alpha = 0
            self.view.layoutIfNeeded()

            UIView.animate(withDuration: 0.25) {
                self.successContainer.alpha = 1
            }
        })

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            #if DEBUG
            if self._previewState != nil { return }
            #endif
            self.dismiss(animated: true)
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: Strings.error,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: CommonStrings.ok, style: .default) { [weak self] _ in
            self?.manager.resetPurchaseState()
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

import SwiftUI

@available(iOS 17.0, *)
private struct TipJarPreview: UIViewControllerRepresentable {
    let state: TipJarViewController.PreviewState

    func makeUIViewController(context: Context) -> TipJarViewController {
        TipJarViewController(previewState: state)
    }

    func updateUIViewController(_ uiViewController: TipJarViewController, context: Context) {}
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Normal") {
    TipJarPreview(state: .normal)
        .preferredColorScheme(.light)
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Internet Gate") {
    TipJarPreview(state: .gate)
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Success") {
    TipJarPreview(state: .success)
}

@available(iOS 17.0, *)
#Preview("Tip Jar — Failed") {
    TipJarPreview(state: .failed)
}

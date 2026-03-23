//
//  SimilarPhotosHelpSheet.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 21.02.2026.
//

import UIKit

private enum Strings {
    static let tapToToggle = "Tap photos\nto toggle"
    static let keep = "Keep"
    static let keepDesc = "Won't be affect"
    static let delete = "Delete"
    static let deleteDesc = "Moves to bin"
    static let store = "Store"
    static let storeDesc = "Saves to album"
    static let storeHint = "Tap the button to\nselect for store"
    static let confirmHint = "Tap Confirm to apply your choices"
    static let gotIt = "Got it!"
}

final class SimilarPhotosHelpSheet: UIViewController {
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let row1: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    private let titleIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let view = UIImageView(image: UIImage(systemName: "hand.tap", withConfiguration: config))
        view.tintColor = .label
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.tapToToggle
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let titleSection: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }()

    private let row1Left = UIView()

    private let row1Right: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.distribution = .fillEqually
        return stack
    }()

    private let row2: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fill
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    private lazy var storeHintIcon: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            systemImage: "archivebox.fill",
            style: .regular,
            backgroundColor: .clear,
            foregroundColor: ThemeManager.Colors.statusYellow,
            iconSize: 14,
            contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
        button.addTarget(self, action: #selector(handleFakeStoreTap), for: .touchUpInside)
        return button
    }()

    private let storeHintLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.storeHint
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let storeHintSection: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.setContentHuggingPriority(.required, for: .horizontal)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return stack
    }()

    private let row2Left = UIView()
    private let row2Right = UIView()

    private var storeCard: UIView!
    private var keepCard: UIView!
    private var deleteCard: UIView!

    private let confirmIcon: UIImageView = {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let view = UIImageView(image: UIImage(systemName: "checkmark.square.fill", withConfiguration: config))
        view.tintColor = .textSecondary
        view.contentMode = .scaleAspectFit
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }()

    private let confirmLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.confirmHint
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .textSecondary
        return label
    }()

    private let confirmStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.distribution = .fill
        return stack
    }()

    private let confirmContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        return view
    }()

    private lazy var gotItButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: Strings.gotIt,
            style: .prominent,
            backgroundColor: .systemBlue,
            foregroundColor: .white,
            contentInsets: NSDirectionalEdgeInsets(top: 14, leading: 20, bottom: 14, trailing: 20)
        )
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        button.addTarget(self, action: #selector(handleGotIt), for: .touchUpInside)
        return button
    }()

    init() {
        super.init(nibName: nil, bundle: nil)

        modalPresentationStyle = .pageSheet

        if let sheet = sheetPresentationController {
            sheet.detents = [.medium()]
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
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        titleSection.addArrangedSubview(titleIcon)
        titleSection.addArrangedSubview(titleLabel)
        titleSection.translatesAutoresizingMaskIntoConstraints = false
        row1Left.addSubview(titleSection)

        keepCard = createStateCard(
            icon: "checkmark.circle.fill", color: ThemeManager.Colors.statusGreen, label: Strings.keep,
            subtitle: Strings.keepDesc)
        deleteCard = createStateCard(
            icon: "xmark.circle.fill", color: ThemeManager.Colors.statusRed, label: Strings.delete,
            subtitle: Strings.deleteDesc)

        row1Right.addArrangedSubview(keepCard)
        row1Right.addArrangedSubview(deleteCard)

        row1.addArrangedSubview(row1Left)
        row1.addArrangedSubview(row1Right)

        storeCard = createStateCard(
            icon: "archivebox.fill", color: ThemeManager.Colors.statusYellow, label: Strings.store,
            subtitle: Strings.storeDesc)

        storeHintSection.addArrangedSubview(storeHintIcon)
        storeHintSection.addArrangedSubview(storeHintLabel)
        storeHintSection.translatesAutoresizingMaskIntoConstraints = false
        row2Left.addSubview(storeHintSection)

        storeCard.translatesAutoresizingMaskIntoConstraints = false
        row2Right.addSubview(storeCard)

        row2.addArrangedSubview(row2Left)
        row2.addArrangedSubview(row2Right)

        confirmStack.addArrangedSubview(confirmIcon)
        confirmStack.addArrangedSubview(confirmLabel)
        confirmStack.translatesAutoresizingMaskIntoConstraints = false
        confirmContainer.addSubview(confirmStack)

        contentStack.addArrangedSubview(row1)
        contentStack.addArrangedSubview(row2)
        contentStack.addArrangedSubview(confirmContainer)
        contentStack.addArrangedSubview(gotItButton)

        view.addSubview(contentStack)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            contentStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            
            titleSection.topAnchor.constraint(equalTo: row1Left.topAnchor),
            titleSection.bottomAnchor.constraint(equalTo: row1Left.bottomAnchor),
            titleSection.centerXAnchor.constraint(equalTo: row1Left.centerXAnchor),
            titleSection.leadingAnchor.constraint(greaterThanOrEqualTo: row1Left.leadingAnchor),
            titleSection.trailingAnchor.constraint(lessThanOrEqualTo: row1Left.trailingAnchor),
            
            storeHintSection.topAnchor.constraint(equalTo: row2Left.topAnchor),
            storeHintSection.bottomAnchor.constraint(equalTo: row2Left.bottomAnchor),
            storeHintSection.centerXAnchor.constraint(equalTo: row2Left.centerXAnchor),
            storeHintSection.leadingAnchor.constraint(greaterThanOrEqualTo: row2Left.leadingAnchor),
            storeHintSection.trailingAnchor.constraint(lessThanOrEqualTo: row2Left.trailingAnchor),
            
            storeCard.topAnchor.constraint(equalTo: row2Right.topAnchor),
            storeCard.bottomAnchor.constraint(equalTo: row2Right.bottomAnchor),
            storeCard.centerXAnchor.constraint(equalTo: row2Right.centerXAnchor),
            storeCard.leadingAnchor.constraint(greaterThanOrEqualTo: row2Right.leadingAnchor),
            storeCard.trailingAnchor.constraint(lessThanOrEqualTo: row2Right.trailingAnchor),
            
            confirmStack.topAnchor.constraint(equalTo: confirmContainer.topAnchor, constant: 12),
            confirmStack.centerXAnchor.constraint(equalTo: confirmContainer.centerXAnchor),
            confirmStack.leadingAnchor.constraint(greaterThanOrEqualTo: confirmContainer.leadingAnchor, constant: 16),
            confirmStack.trailingAnchor.constraint(lessThanOrEqualTo: confirmContainer.trailingAnchor, constant: -16),
            confirmStack.bottomAnchor.constraint(equalTo: confirmContainer.bottomAnchor, constant: -12)
        ])
        row2Left.widthAnchor.constraint(equalTo: row2Right.widthAnchor).isActive = true
        row1Left.widthAnchor.constraint(equalTo: row1Right.widthAnchor).isActive = true
        storeCard.widthAnchor.constraint(equalTo: keepCard.widthAnchor).isActive = true
    }

    private func createStateCard(icon: String, color: UIColor, label: String, subtitle: String) -> UIView {
        let cardView = UIView()
        cardView.backgroundColor = color.withAlphaComponent(0.15)
        cardView.layer.cornerRadius = 20
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.heightAnchor.constraint(equalTo: cardView.widthAnchor).isActive = true

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: iconConfig))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: cardView.centerYAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = label
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .textSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2

        let labelStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        labelStack.alignment = .center

        let column = UIStackView(arrangedSubviews: [cardView, labelStack])
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = 8
        return column
    }

    @objc private func handleFakeStoreTap() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [0, -8, 8, -6, 6, -3, 3, 0]
        anim.duration = 0.5
        storeCard.layer.add(anim, forKey: "shake")
    }

    @objc private func handleGotIt() {
        dismiss(animated: true)
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview {
        SimilarPhotosHelpSheet()
    }
#endif

//
//  ActionGripView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 08.11.2026.
//

import UIKit

/// A rounded white column with a Store segment on top and the primary action (Delete or Keep)
/// below it. Both segments are gray with only the icon in the action's color; the counts live in
/// MonthReview's stats pill. MonthReview shows one on each side of the card on the iPhone Duo's
/// inner display held sideways; the segments run the same code as an up, left or right swipe.
final class ActionGripView: UIView {

    var onStoreTap: (() -> Void)?
    var onPrimaryTap: (() -> Void)?

    private enum Layout {
        static let segmentCornerRadius: CGFloat = GeneralConstants.ActionGrip.width / 2 - GeneralConstants.ActionGrip.inset
    }

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = GeneralConstants.ActionGrip.inset
        stack.distribution = .fill
        return stack
    }()

    private let storeButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let primaryButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()


    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.ActionGrip.width / 2
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.07
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 12

        storeButton.addTarget(self, action: #selector(handleStoreTap), for: .touchUpInside)
        primaryButton.addTarget(self, action: #selector(handlePrimaryTap), for: .touchUpInside)

        addSubview(stackView)
        stackView.addArrangedSubview(storeButton)
        stackView.addArrangedSubview(primaryButton)
    }

    private func setupConstraint() {
        let inset = GeneralConstants.ActionGrip.inset
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: GeneralConstants.ActionGrip.width),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: inset),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: inset),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -inset),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -inset),

            storeButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ActionGrip.storeSegmentHeight)
        ])
    }

    // MARK: - Configuration

    /// Both segments are a gray fill with the action's color on the icon only (yellow for Store);
    /// the counts live in the stats pill above the card.
    func configure(primaryTitle: String, primarySystemImage: String, primaryColor: UIColor, storeTitle: String) {
        storeButton.configuration = Self.segmentConfiguration(
            title: storeTitle, systemImage: "archivebox", iconSize: 22,
            background: .tertiarySystemFill, foreground: .label, iconColor: ThemeManager.Colors.statusYellow)

        primaryButton.configuration = Self.segmentConfiguration(
            title: primaryTitle, systemImage: primarySystemImage, iconSize: 28,
            background: .tertiarySystemFill, foreground: .label, iconColor: primaryColor)
    }

    private static func segmentConfiguration(
        title: String, systemImage: String, iconSize: CGFloat, background: UIColor, foreground: UIColor,
        iconColor: UIColor? = nil
    ) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold))
        config.imagePlacement = .top
        config.imagePadding = 8
        config.titleAlignment = .center
        config.titlePadding = 4
        var container = AttributeContainer()
        container.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        config.attributedTitle = AttributedString(title, attributes: container)
        config.baseBackgroundColor = background
        config.baseForegroundColor = foreground
        if let iconColor = iconColor {
            config.imageColorTransformer = UIConfigurationColorTransformer { _ in iconColor }
        }
        config.cornerStyle = .fixed
        config.background.cornerRadius = Layout.segmentCornerRadius
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        return config
    }

    // MARK: - Actions

    @objc private func handleStoreTap() {
        onStoreTap?()
    }

    @objc private func handlePrimaryTap() {
        onPrimaryTap?()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    private struct ActionGripPreview: UIViewRepresentable {
        let isDelete: Bool

        func makeUIView(context: Context) -> ActionGripView {
            let grip = ActionGripView()
            grip.configure(
                primaryTitle: isDelete ? "Delete" : "Keep",
                primarySystemImage: isDelete ? "trash" : "checkmark",
                primaryColor: isDelete ? ThemeManager.Colors.statusRed : ThemeManager.Colors.statusGreen,
                storeTitle: "Store")
            return grip
        }

        func updateUIView(_ uiView: ActionGripView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Grips") {
        HStack(spacing: 40) {
            ActionGripPreview(isDelete: true).frame(width: 104, height: 520)
            ActionGripPreview(isDelete: false).frame(width: 104, height: 520)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
    }
#endif

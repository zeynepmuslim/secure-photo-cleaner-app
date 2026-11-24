//
//  AccessStatusCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let fullTitle = NSLocalizedString("accessCard.fullTitle", comment: "Access card title: full photo library access")
    static let limitedTitle = NSLocalizedString("accessCard.limitedTitle", comment: "Access card title: limited photo library access")
    static let notAskedTitle = NSLocalizedString("accessCard.notAskedTitle", comment: "Access card title: access not asked yet")
    static let offTitle = NSLocalizedString("accessCard.offTitle", comment: "Access card title: access denied or restricted")
    static let fullMessage = NSLocalizedString("accessCard.fullMessage", comment: "Access card text: full access")
    static let limitedNoneMessage = NSLocalizedString("accessCard.limitedNoneMessage", comment: "Access card text: limited access with no items picked")
    static let notAskedMessage = NSLocalizedString("accessCard.notAskedMessage", comment: "Access card text: access not asked yet")
    static let offMessage = NSLocalizedString("accessCard.offMessage", comment: "Access card text: access is off")
    static let allowFullAccess = NSLocalizedString("accessCard.allowFullAccess", comment: "Access card button: open Settings to allow full access")
    static func limitedMessage(count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("accessCard.limitedMessage", comment: "Access card text: limited access, how many items were picked"),
            count)
    }
}

/// How much of the photo library Purgio can see, as a card: a status capsule beside the
/// level's title over a short text, and optionally a full-width gray button under them.
/// The months list's empty and permission states show it as their `EmptyStateView` accessory;
/// reuse it wherever an access level shows.
final class AccessStatusCardView: UIView {

    /// The access level. It sets the mark's color and the title.
    enum Status {
        case full
        case limited
        case notAsked
        case off

        fileprivate var color: UIColor {
            switch self {
            case .full: return .systemGreen
            case .limited: return .systemYellow
            case .notAsked: return .systemGray3
            case .off: return .systemRed
            }
        }

        fileprivate var title: String {
            switch self {
            case .full: return Strings.fullTitle
            case .limited: return Strings.limitedTitle
            case .notAsked: return Strings.notAskedTitle
            case .off: return Strings.offTitle
            }
        }
    }

    private enum Layout {
        static let inset = GeneralConstants.EdgePadding.cardInner
        static let markToText: CGFloat = 10
        static let titleSize: CGFloat = 15
        static let titleToText: CGFloat = 3
        static let rowToButton: CGFloat = 14
        static let buttonFontSize: CGFloat = 15
    }

    private let markView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = GeneralConstants.LegendCapsule.width / 2
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Layout.titleSize, weight: .semibold)
        label.textColor = .textPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let textLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.regularCaption
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// The mark, title and text as one VoiceOver element.
    private let summaryView: UIView = {
        let view = UIView()
        view.isAccessibilityElement = true
        view.accessibilityTraits = .staticText
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var button: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.isHidden = true
        button.addTarget(self, action: #selector(handleButtonTap), for: .touchUpInside)
        return button
    }()

    private var onButton: (() -> Void)?
    private var buttonTitle: String?
    private var summaryToBottomConstraint: NSLayoutConstraint?
    private var buttonConstraints: [NSLayoutConstraint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .cardBackground
        layer.cornerRadius = GeneralConstants.CornerRadius.card
        layer.cornerCurve = .continuous

        addSubview(summaryView)
        summaryView.addSubview(markView)
        summaryView.addSubview(titleLabel)
        summaryView.addSubview(textLabel)
        addSubview(button)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: AccessStatusCardView, _: UITraitCollection) in
                self.applyButtonStyle()
            }
        }
    }

    private func setupConstraint() {
        let summaryToBottom = summaryView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.inset)
        summaryToBottomConstraint = summaryToBottom
        buttonConstraints = [
            button.topAnchor.constraint(equalTo: summaryView.bottomAnchor, constant: Layout.rowToButton),
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.inset),
            button.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.inset),
            button.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.mediumLarge),
            button.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.inset)
        ]

        NSLayoutConstraint.activate([
            summaryView.topAnchor.constraint(equalTo: topAnchor, constant: Layout.inset),
            summaryView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.inset),
            summaryView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.inset),
            summaryToBottom,

            // The mark sits beside the title's line, not the whole column
            markView.leadingAnchor.constraint(equalTo: summaryView.leadingAnchor),
            markView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            markView.widthAnchor.constraint(equalToConstant: GeneralConstants.LegendCapsule.width),
            markView.heightAnchor.constraint(equalToConstant: GeneralConstants.LegendCapsule.height),

            titleLabel.topAnchor.constraint(equalTo: summaryView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: markView.trailingAnchor, constant: Layout.markToText),
            titleLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor),

            textLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.titleToText),
            textLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            textLabel.trailingAnchor.constraint(equalTo: summaryView.trailingAnchor),
            textLabel.bottomAnchor.constraint(equalTo: summaryView.bottomAnchor)
        ])
    }

    // MARK: - Configure

    /// - Parameters:
    ///   - status: the access level; sets the mark's color and the title.
    ///   - text: nil shows the level's standard text. `.limited` has none of its own: pass
    ///     `limitedText(itemCount:)`.
    ///   - buttonTitle: with `onButton`, a full-width gray button under the row.
    func configure(status: Status, text: String? = nil, buttonTitle: String? = nil, onButton: (() -> Void)? = nil) {
        markView.backgroundColor = status.color
        titleLabel.text = status.title
        textLabel.text = text ?? Self.standardText(for: status)
        summaryView.accessibilityLabel = [titleLabel.text, textLabel.text].compactMap { $0 }.joined(separator: ", ")

        let showsButton = buttonTitle != nil && onButton != nil
        self.onButton = showsButton ? onButton : nil
        self.buttonTitle = showsButton ? buttonTitle : nil
        button.isHidden = !showsButton
        // Deactivate before activating, so the two bottoms never hold at once
        if showsButton {
            summaryToBottomConstraint?.isActive = false
            NSLayoutConstraint.activate(buttonConstraints)
        } else {
            NSLayoutConstraint.deactivate(buttonConstraints)
            summaryToBottomConstraint?.isActive = true
        }
        applyButtonStyle()
    }

    /// The limited level's text: how many items were picked, or that none were.
    static func limitedText(itemCount: Int) -> String {
        itemCount > 0 ? Strings.limitedMessage(count: itemCount) : Strings.limitedNoneMessage
    }

    /// "Allow full access", the limited level's button.
    static var allowFullAccessTitle: String { Strings.allowFullAccess }

    private static func standardText(for status: Status) -> String {
        switch status {
        case .full: return Strings.fullMessage
        case .limited: return Strings.limitedNoneMessage
        case .notAsked: return Strings.notAskedMessage
        case .off: return Strings.offMessage
        }
    }

    private func applyButtonStyle() {
        guard let buttonTitle else { return }
        button.configure(
            title: buttonTitle,
            style: .regular,
            backgroundColor: UIColor.systemGray5.resolvedColor(with: traitCollection),
            foregroundColor: UIColor.label.resolvedColor(with: traitCollection),
            fontSize: Layout.buttonFontSize,
            fontWeight: .semibold)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyButtonStyle()
        }
    }

    // MARK: - Actions

    @objc private func handleButtonTap() {
        onButton?()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let stack = UIStackView()
    stack.axis = .vertical
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false

    let full = AccessStatusCardView()
    full.configure(status: .full)
    let limited = AccessStatusCardView()
    limited.configure(
        status: .limited, text: AccessStatusCardView.limitedText(itemCount: 12),
        buttonTitle: AccessStatusCardView.allowFullAccessTitle, onButton: {})
    let notAsked = AccessStatusCardView()
    notAsked.configure(status: .notAsked)
    let off = AccessStatusCardView()
    off.configure(status: .off)
    [full, limited, notAsked, off].forEach { stack.addArrangedSubview($0) }

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
        stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}
#endif

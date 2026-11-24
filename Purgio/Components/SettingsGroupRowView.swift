//
//  SettingsGroupRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

/// One row of a `SettingsGroupView` (iPhone Duo split layouts), laid out like `SettingsInfoCardView`:
/// a colored icon glyph and the title on one line, the optional subtitle under both, and a
/// trailing accessory (toggle, navigation, value, menu or text).
final class SettingsGroupRowView: UIControl {

    /// Where a tap leads; its indicator tells the user before they tap
    enum Destination {
        /// Pushes a screen: chevron right
        case push
        /// Presents a sheet over Settings: chevron up
        case sheet
        /// Leaves the app (the Settings app, Safari): arrow up-right
        case external

        var symbolName: String {
            switch self {
            case .push: return "chevron.right"
            case .sheet: return "chevron.up"
            case .external: return "arrow.up.right"
            }
        }
    }

    enum Accessory {
        case toggle
        case navigation(Destination)
        case value(String, Destination)
        case menu(title: String, menu: UIMenu)
        case text(String)
    }

    var onTap: (() -> Void)?
    var onToggle: ((Bool) -> Void)?

    /// Hidden on the first visible row of a group (set by `SettingsGroupView`)
    var showsSeparator: Bool = true {
        didSet { separatorView.isHidden = !showsSeparator }
    }

    private enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let verticalPadding: CGFloat = 14
        static let iconSlotSize: CGFloat = 24
        static let iconPointSize: CGFloat = 20
        static let iconToTitle: CGFloat = 12
        static let titleToSubtitle: CGFloat = 8
        static let minimumHeight: CGFloat = 56
    }

    private var accessory: Accessory = .navigation(.push)

    /// Fixed-width slot, so titles line up whatever the symbol's width
    private let iconSlot: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.isHidden = true
        return label
    }()

    /// The icon and the title, one line
    private let headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = Layout.iconToTitle
        return stack
    }()

    /// The header over the subtitle, which starts under the icon
    private let labelsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.titleToSubtitle
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textColor = .secondaryLabel
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        return label
    }()

    /// The destination's indicator, or the menu's up-down chevron
    private let indicatorView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .tertiaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        return imageView
    }()

    private let toggleSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.onTintColor = .systemGreen
        toggle.setContentCompressionResistancePriority(.required, for: .horizontal)
        return toggle
    }()

    private let accessoryStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Covers the whole row for `.menu`, so a tap anywhere opens the menu
    private let menuButton: UIButton = {
        let button = UIButton(type: .system)
        button.showsMenuAsPrimaryAction = true
        button.isHidden = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .separator
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Configuration

    /// The icon is a colored glyph, matching `SettingsInfoCardView`'s icons
    func configure(iconName: String, iconColor: UIColor, title: String,
                   subtitle: String? = nil, accessory: Accessory) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: Layout.iconPointSize, weight: .medium)
        iconView.image = UIImage(systemName: iconName, withConfiguration: symbolConfig)
        iconView.tintColor = iconColor
        titleLabel.text = title
        subtitleLabel.text = subtitle
        subtitleLabel.isHidden = subtitle == nil
        apply(accessory)
    }

    func setToggleOn(_ isOn: Bool, animated: Bool = false) {
        guard toggleSwitch.isOn != isOn else { return }
        toggleSwitch.setOn(isOn, animated: animated)
    }

    func setMenu(title: String, menu: UIMenu) {
        apply(.menu(title: title, menu: menu))
    }

    private func apply(_ accessory: Accessory) {
        self.accessory = accessory
        accessoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        menuButton.isHidden = true
        menuButton.menu = nil

        switch accessory {
        case .toggle:
            accessoryStack.addArrangedSubview(toggleSwitch)
        case .navigation(let destination):
            setIndicator(destination.symbolName)
            accessoryStack.addArrangedSubview(indicatorView)
        case .value(let value, let destination):
            valueLabel.text = value
            setIndicator(destination.symbolName)
            accessoryStack.addArrangedSubview(valueLabel)
            accessoryStack.addArrangedSubview(indicatorView)
        case .menu(let title, let menu):
            valueLabel.text = title
            setIndicator("chevron.up.chevron.down")
            accessoryStack.addArrangedSubview(valueLabel)
            accessoryStack.addArrangedSubview(indicatorView)
            menuButton.menu = menu
            menuButton.isHidden = false
        case .text(let text):
            valueLabel.text = text
            accessoryStack.addArrangedSubview(valueLabel)
        }
        updateAccessibility()
    }

    /// VoiceOver reads a tappable or text row as one element; a toggle or menu row leaves the
    /// row to its control, which carries the row's title
    private func updateAccessibility() {
        let title = titleLabel.text ?? ""
        let label = [title, subtitleLabel.text].compactMap { $0 }.joined(separator: ", ")
        let value: String?
        switch accessory {
        case .value, .menu, .text: value = valueLabel.text
        case .toggle, .navigation: value = nil
        }
        switch accessory {
        case .toggle:
            isAccessibilityElement = false
            toggleSwitch.accessibilityLabel = label
        case .menu:
            isAccessibilityElement = false
            menuButton.accessibilityLabel = title
            menuButton.accessibilityValue = value
        case .navigation, .value, .text:
            isAccessibilityElement = true
            accessibilityLabel = label
            accessibilityValue = value
        }
        accessibilityTraits = isTappable ? .button : .staticText
    }

    private var isTappable: Bool {
        switch accessory {
        case .navigation, .value: return true
        case .toggle, .menu, .text: return false
        }
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        iconSlot.addSubview(iconView)
        headerStack.addArrangedSubview(iconSlot)
        headerStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(headerStack)
        labelsStack.addArrangedSubview(subtitleLabel)
        addSubview(labelsStack)
        addSubview(accessoryStack)
        addSubview(menuButton)
        addSubview(separatorView)

        toggleSwitch.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
        addTarget(self, action: #selector(handleTap), for: .touchUpInside)

        let padding = Layout.horizontalPadding
        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.minimumHeight),

            iconSlot.widthAnchor.constraint(equalToConstant: Layout.iconSlotSize),
            iconSlot.heightAnchor.constraint(equalToConstant: Layout.iconSlotSize),
            iconView.centerXAnchor.constraint(equalTo: iconSlot.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconSlot.centerYAnchor),

            labelsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            labelsStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: Layout.verticalPadding),
            labelsStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Layout.verticalPadding),
            labelsStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            labelsStack.trailingAnchor.constraint(lessThanOrEqualTo: accessoryStack.leadingAnchor, constant: -12),

            accessoryStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
            accessoryStack.centerYAnchor.constraint(equalTo: centerYAnchor),

            menuButton.topAnchor.constraint(equalTo: topAnchor),
            menuButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            menuButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            menuButton.bottomAnchor.constraint(equalTo: bottomAnchor),

            // Inset to the content, which the subtitle spans from the icon on
            separatorView.topAnchor.constraint(equalTo: topAnchor),
            separatorView.leadingAnchor.constraint(equalTo: labelsStack.leadingAnchor),
            separatorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        // The labels take the room left by the accessory
        labelsStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let fillWidth = labelsStack.trailingAnchor.constraint(
            equalTo: accessoryStack.leadingAnchor, constant: -12)
        fillWidth.priority = .defaultHigh
        fillWidth.isActive = true

        apply(.navigation(.push))
    }

    private func setIndicator(_ symbolName: String) {
        let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        indicatorView.image = UIImage(systemName: symbolName, withConfiguration: config)
    }

    // MARK: - Actions

    @objc private func toggleChanged() {
        onToggle?(toggleSwitch.isOn)
    }

    @objc private func handleTap() {
        guard isTappable else { return }
        HapticFeedbackManager.shared.impact(intensity: .light)
        onTap?()
    }

    override var isHighlighted: Bool {
        didSet {
            guard isTappable else { return }
            UIView.animate(withDuration: 0.15) {
                self.backgroundColor = self.isHighlighted ? UIColor.label.withAlphaComponent(0.06) : .clear
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let group = SettingsGroupView()
    let internet = SettingsGroupRowView()
    internet.configure(iconName: "network", iconColor: .systemBlue, title: "Internet Access",
                       subtitle: "iCloud photos download in full quality.", accessory: .toggle)
    let language = SettingsGroupRowView()
    language.configure(iconName: "character.bubble", iconColor: .systemBlue, title: "App Language",
                       accessory: .value("English", .external))
    let version = SettingsGroupRowView()
    version.configure(iconName: "info.circle", iconColor: .systemGray, title: "Version", accessory: .text("1.1"))
    group.configure(rows: [internet, language, version])

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(group)
    NSLayoutConstraint.activate([
        group.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
        group.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
        group.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16)
    ])
    return container
}
#endif

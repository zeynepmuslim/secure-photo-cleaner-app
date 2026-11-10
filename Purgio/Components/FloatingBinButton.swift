//
//  FloatingBinButton.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.01.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let title = NSLocalizedString("floatingBin.title", comment: "Bin button title when it has room for one")
    static func titleWithCount(_ count: String) -> String {
        String(format: NSLocalizedString("floatingBin.titleWithCount", comment: "Bin button title with its count, e.g. Bin · 14"), count)
    }
}

class FloatingBinButton: UIButton {

    enum DisplayMode: Equatable {
        case count(Int)   // Normal: "5"
        case increment(Int)   // Swiping: "+3"
        case wide   // Delete Bin: "Delete All"
    }

    private var widthConstraint: NSLayoutConstraint?
    private var isWideMode = false
    /// Set while a screen's slot gives the button room for a title ("Bin · 14" instead of "14").
    private var showsTitle = false
    private(set) var currentMode: DisplayMode = .count(0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupButton()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }

    private func setupButton() {
        accessibilityIdentifier = "floatingBinButton"
        translatesAutoresizingMaskIntoConstraints = false

        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.prominentGlass()
            config.image = UIImage(
                systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            config.imagePadding = 8
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            configuration = config
            tintColor = ThemeManager.Colors.statusRed
        } else {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(
                systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            config.imagePadding = 8
            config.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
            config.baseBackgroundColor = ThemeManager.Colors.statusRed
            config.baseForegroundColor = .white
            config.cornerStyle = .capsule
            configuration = config
        }
    }

    func updateCount(_ count: Int, animated: Bool = true) {
        currentMode = .count(count)
        guard var config = configuration else { return }

        config.image = UIImage(
            systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        config.attributedTitle = countTitle(count > 0 ? "\(count)" : nil)

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.configuration = config
                self.layoutIfNeeded()
            }
        } else {
            configuration = config
        }
    }

    func updateIncrement(_ count: Int, animated: Bool = true) {
        currentMode = .increment(count)
        guard var config = configuration else { return }

        config.image = UIImage(
            systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))

        config.attributedTitle = countTitle(count > 0 ? "+\(count)" : nil)

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                self.configuration = config
                self.layoutIfNeeded()
            }
        } else {
            configuration = config
        }
    }

    func setMode(_ mode: DisplayMode) {
        currentMode = mode
        switch mode {
        case .count(let count):
            if isWideMode {
                morphToCompact(count: count, animated: true)
            } else {
                updateCount(count)
            }
        case .increment(let count):
            if isWideMode {
                isWideMode = false
            }
            updateIncrement(count)
        case .wide:
            morphToWide(animated: true)
        }
    }

    func morphToWide(animated: Bool = true) {
        guard !isWideMode else { return }
        isWideMode = true
        currentMode = .wide

        guard var config = configuration else { return }

        var container = AttributeContainer()
        container.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        config.attributedTitle = AttributedString("Delete All", attributes: container)

        configuration = config

        let animations = {
            if let widthConstraint = self.widthConstraint {
                widthConstraint.isActive = false
            }
            self.superview?.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8) {
                animations()
            }
        } else {
            animations()
        }
    }

    func setWideTitle(_ title: String, enabled: Bool) {
        guard var config = configuration else { return }
        var container = AttributeContainer()
        container.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        config.attributedTitle = AttributedString(title, attributes: container)
        configuration = config
        isEnabled = enabled
        alpha = enabled ? 1.0 : 0.5
    }

    func morphToCompact(count: Int, animated: Bool = true) {
        guard isWideMode else { return }
        isWideMode = false
        currentMode = .count(count)

        isEnabled = true
        alpha = 1.0

        guard var config = configuration else { return }

        config.image = UIImage(
            systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))

        config.attributedTitle = countTitle(count > 0 ? "\(count)" : nil)

        configuration = config

        let animations = {
            if let widthConstraint = self.widthConstraint {
                widthConstraint.isActive = true
            }
            self.superview?.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8) {
                animations()
            }
        } else {
            animations()
        }
    }

    /// Shows "Bin · 14" (or "Bin" while empty) instead of the bare count, for a slot wide enough.
    func setShowsTitle(_ shows: Bool) {
        guard shows != showsTitle else { return }
        showsTitle = shows
        switch currentMode {
        case .count(let count): updateCount(count, animated: false)
        case .increment(let count): updateIncrement(count, animated: false)
        case .wide: break
        }
    }

    /// The count or increment text, with the title in front while `showsTitle` is on.
    private func countTitle(_ number: String?) -> AttributedString? {
        let text: String
        if showsTitle {
            text = number.map { Strings.titleWithCount($0) } ?? Strings.title
        } else if let number = number {
            text = number
        } else {
            return nil
        }
        var container = AttributeContainer()
        container.font = UIFont.monospacedDigitSystemFont(ofSize: 18, weight: .bold)
        return AttributedString(text, attributes: container)
    }

    func setWidthConstraint(_ constraint: NSLayoutConstraint) {
        widthConstraint = constraint
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Default") {
        let button = FloatingBinButton()
        return button
    }

    @available(iOS 17.0, *)
    #Preview("With Count") {
        let button = FloatingBinButton()
        button.updateCount(5)
        return button
    }

    @available(iOS 17.0, *)
    #Preview("Wide Mode") {
        let button = FloatingBinButton()
        button.morphToWide(animated: false)
        return button
    }

    @available(iOS 17.0, *)
    #Preview("Increment Mode") {
        let button = FloatingBinButton()
        button.updateIncrement(3)
        return button
    }
#endif

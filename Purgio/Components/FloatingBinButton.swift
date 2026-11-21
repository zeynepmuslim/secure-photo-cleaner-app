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

    // MARK: - Layout

    /// The button's own inner padding (not screen padding, so not `EdgePadding.content`).
    private enum Layout {
        static let verticalInset: CGFloat = 16
        static let horizontalInset: CGFloat = 20
        static let imagePadding: CGFloat = 8
        /// Between icon and count in a screen's slot, where width is short.
        static let slotImagePadding: CGFloat = 6
        /// A slot shows counts up to this, then "99+", so a slot sized to its count stays short.
        static let slotCountCap = 99
    }

    /// Lays out a button for `slotWidth(forCount:)`; never shown.
    private static let sizingButton: FloatingBinButton = {
        let button = FloatingBinButton()
        button.setFitsSlot(true)
        return button
    }()

    /// The width a slot needs for the icon and this count ("99+" above 99), never narrower than
    /// the standard slot (`BinSlot.compactWidth`), so a short count keeps room around it. A screen
    /// that sizes its slot to the button (the month hub's bottom row) passes the count it configured.
    static func slotWidth(forCount count: Int) -> CGFloat {
        let button = sizingButton
        button.updateCount(count, animated: false)
        let fitting = button.systemLayoutSizeFitting(
            CGSize(width: UIView.layoutFittingCompressedSize.width, height: GeneralConstants.ButtonSize.large),
            withHorizontalFittingPriority: .fittingSizeLevel,
            verticalFittingPriority: .required).width
        return max(GeneralConstants.BinSlot.compactWidth, ceil(fitting))
    }

    enum DisplayMode: Equatable {
        case count(Int)   // Normal: "5"
        case increment(Int)   // Swiping: "+3"
        case wide   // Delete Bin: "Delete All"
    }

    private var widthConstraint: NSLayoutConstraint?
    private var isWideMode = false
    /// Set while a screen's slot gives the button room for a title ("Bin · 14" instead of "14").
    private var showsTitle = false
    /// Set while the button sits in a screen's slot (as narrow as 96pt): tighter insets and a
    /// count that stays on one line beside the icon ("99+" above 99).
    private var fitsSlot = false
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
            config.imagePadding = Layout.imagePadding
            config.contentInsets = NSDirectionalEdgeInsets(
                top: Layout.verticalInset, leading: Layout.horizontalInset,
                bottom: Layout.verticalInset, trailing: Layout.horizontalInset)
            configuration = config
            tintColor = ThemeManager.Colors.statusRed
        } else {
            var config = UIButton.Configuration.filled()
            config.image = UIImage(
                systemName: "trash", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            config.imagePadding = Layout.imagePadding
            config.contentInsets = NSDirectionalEdgeInsets(
                top: Layout.verticalInset, leading: Layout.horizontalInset,
                bottom: Layout.verticalInset, trailing: Layout.horizontalInset)
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
        config.attributedTitle = countTitle(count > 0 ? countText(count) : nil)
        applySlotMetrics(to: &config)

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

        config.attributedTitle = countTitle(count > 0 ? "+" + (fitsSlot ? count.compactFormatted : "\(count)") : nil)
        applySlotMetrics(to: &config)

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

        config.attributedTitle = countTitle(count > 0 ? countText(count) : nil)
        applySlotMetrics(to: &config)

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

    /// Tighter metrics in a slot, so a two- or three-digit count stays on one line in 96pt.
    func setFitsSlot(_ fits: Bool) {
        guard fits != fitsSlot else { return }
        fitsSlot = fits
        switch currentMode {
        case .count(let count): updateCount(count, animated: false)
        case .increment(let count): updateIncrement(count, animated: false)
        case .wide: break
        }
    }

    private func applySlotMetrics(to config: inout UIButton.Configuration) {
        let horizontal = fitsSlot ? GeneralConstants.EdgePadding.small : Layout.horizontalInset
        config.contentInsets = NSDirectionalEdgeInsets(
            top: Layout.verticalInset, leading: horizontal, bottom: Layout.verticalInset, trailing: horizontal)
        config.imagePadding = fitsSlot ? Layout.slotImagePadding : Layout.imagePadding
        config.titleLineBreakMode = fitsSlot ? .byTruncatingTail : .byWordWrapping
    }

    /// The number as shown: "99+" above 99 in a slot, where width is short.
    private func countText(_ count: Int) -> String {
        guard fitsSlot else { return "\(count)" }
        return count > Layout.slotCountCap ? "\(Layout.slotCountCap)+" : "\(count)"
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

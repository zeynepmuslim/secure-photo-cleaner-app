//
//  MainTabBarController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 3.01.2026.
//

import UIKit

extension Notification.Name {
    static let deleteBinButtonTapped = Notification.Name("deleteBinButtonTapped")
    static let deleteBinEditStateDidChange = Notification.Name("deleteBinEditStateDidChange")
}

// MARK: - Strings

private enum Strings {
    static let deleteAll = NSLocalizedString("mainTabBar.deleteAll", comment: "Delete All button title")
    static let delete = CommonStrings.delete
}

// MARK: - FloatingBinButtonController Protocol

/// Where the global bin button sits.
enum BinButtonPlacement: Equatable {
    /// Floating at the trailing bottom (wide on Delete Bin).
    case standard
    /// A slot a screen lays out in its own bottom row, in window coordinates
    /// (MonthReview on the iPhone Duo's inner display held sideways).
    case slot(CGRect)
}

protocol FloatingBinButtonController: AnyObject {
    func configureBinButton(
        mode: FloatingBinButton.DisplayMode,
        monthKey: String?,
        monthTitle: String?,
        tapHandler: (() -> Void)?)
    func configureWideBinButton(
        title: String,
        monthKey: String?,
        monthTitle: String?,
        tapHandler: (() -> Void)?)
    func showBinButton()
    func hideBinButton()
    func setBinButtonPlacement(_ placement: BinButtonPlacement)
}

class MainTabBarController: UITabBarController, UINavigationControllerDelegate {
    private let binButton = FloatingBinButton()
    private let deleteBinStore = DeleteBinStore.shared
    private var isTransitioning = false
    private var binButtonTrailingConstraint: NSLayoutConstraint?
    private var binButtonLeadingConstraint: NSLayoutConstraint?
    private var binButtonFixedWidthConstraint: NSLayoutConstraint?
    private var binButtonAboveTabBarConstraint: NSLayoutConstraint?
    private var binButtonAlignedWithTabBarConstraint: NSLayoutConstraint?
    private var isDeleteBinEditing = false
    private var binButtonPlacement: BinButtonPlacement = .standard
    private var binButtonStandardBottomConstraint: NSLayoutConstraint?
    private var binSlotLeadingConstraint: NSLayoutConstraint?
    private var binSlotWidthConstraint: NSLayoutConstraint?
    private var binSlotBottomConstraint: NSLayoutConstraint?
    private var isBinButtonInSlot: Bool {
        if case .slot = binButtonPlacement { return true }
        return false
    }

    // Context for month-filtered navigation
    private var currentMonthContext: (key: String, title: String)?
    private var customTapHandler: (() -> Void)?
    private var savedMode: FloatingBinButton.DisplayMode?

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self

        setupBinButton()
        updateBinButton()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateBinButton),
            name: .deleteBinCountDidChange,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeleteBinEditStateChange(_:)),
            name: .deleteBinEditStateDidChange,
            object: nil
        )
    }

    override var viewControllers: [UIViewController]? {
        didSet {
            viewControllers?.compactMap { $0 as? UINavigationController }.forEach { $0.delegate = self }
        }
    }

    private func setupBinButton() {
        binButton.addTarget(self, action: #selector(handleBinTap), for: .touchUpInside)

        view.addSubview(binButton)
        binButton.translatesAutoresizingMaskIntoConstraints = false

        let binButtonBottom: NSLayoutConstraint
        if #available(iOS 26.0, *) {
            binButtonTrailingConstraint = binButton.trailingAnchor.constraint(
                equalTo: contentLayoutGuide.trailingAnchor, constant: -GeneralConstants.EdgePadding.medium)
            binButtonLeadingConstraint = binButton.leadingAnchor.constraint(
                equalTo: contentLayoutGuide.leadingAnchor, constant: GeneralConstants.EdgePadding.medium)

            binButtonAboveTabBarConstraint = binButton.bottomAnchor.constraint(
                equalTo: contentLayoutGuide.bottomAnchor,
                constant: -GeneralConstants.Spacer.buttonBottom)
            // Vertical rail: same bottom edge as Home's content (DuoLayout.RailPadding)
            binButtonAlignedWithTabBarConstraint = binButton.bottomAnchor.constraint(
                equalTo: view.bottomAnchor, constant: -DuoLayout.RailPadding.bottom)
            binButtonBottom = binButtonAboveTabBarConstraint!
        } else {
            binButtonTrailingConstraint = binButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -GeneralConstants.EdgePadding.medium)
            binButtonLeadingConstraint = binButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: GeneralConstants.EdgePadding.medium)
            binButtonBottom = binButton.bottomAnchor.constraint(
                equalTo: tabBar.topAnchor,
                constant: -GeneralConstants.Spacer.buttonBottom)
        }

        binButtonStandardBottomConstraint = binButtonBottom
        NSLayoutConstraint.activate([
            binButtonTrailingConstraint!,
            binButtonBottom,
            binButton.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large)
        ])

        binSlotLeadingConstraint = binButton.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        binSlotWidthConstraint = binButton.widthAnchor.constraint(equalToConstant: 0)
        binSlotBottomConstraint = binButton.bottomAnchor.constraint(equalTo: view.topAnchor)

        binButtonFixedWidthConstraint = binButton.widthAnchor.constraint(equalToConstant: 180)
        binButtonFixedWidthConstraint?.priority = .defaultHigh
    }

    @objc private func updateBinButton() {
        // If we're on DeleteBin (wide mode), clear savedMode so morphButtonToCompact
        // won't restore the old mode. The returning VC's viewWillAppear will reconfigure.
        if case .wide = binButton.currentMode {
            // If a VC is controlling the button (customTapHandler set), don't override its title
            if customTapHandler == nil {
                savedMode = nil
                binButton.setWideTitle(Strings.deleteAll, enabled: deleteBinStore.count > 0)
            }
            updateVisibility()
            return
        }

        // If in increment mode, let the owning VC handle the update via its own notification handler
        // Don't override to count mode here
        if case .increment = binButton.currentMode {
            updateVisibility()
            return
        }

        binButton.updateCount(deleteBinStore.count)
        updateVisibility()
    }

    private func updateVisibility(immediate: Bool = false, animated: Bool = true) {
        if isTransitioning && !immediate {
            return
        }

        let isHomeTab = selectedIndex == 0
        let isSettingsTab = selectedIndex == 3
        var shouldHide = isHomeTab || isSettingsTab

        // If top VC is a bin-aware screen, show the button even on Home/Settings tabs
        // edge case -> HOmevc's feel lucky navigate to MonthReview which should have bin
        if shouldHide,
            let navController = selectedViewController as? UINavigationController,
            let topVC = navController.topViewController,
            topVC is MonthReviewViewController
                || topVC is MonthFilterCardsViewController
                || topVC is DeleteBinViewController
                || topVC is SimilarPhotosViewController
        {
            shouldHide = false
        }

        let targetAlpha: CGFloat = shouldHide ? 0 : 1

        if animated {
            UIView.animate(withDuration: 0.25) {
                self.binButton.alpha = targetAlpha
            }
        } else {
            binButton.alpha = targetAlpha
        }
    }

    @objc private func handleBinTap() {
        if let navController = selectedViewController as? UINavigationController,
            navController.topViewController is DeleteBinViewController
        {
            NotificationCenter.default.post(name: .deleteBinButtonTapped, object: nil)
        } else {
            if let customHandler = customTapHandler {
                customHandler()
                return
            }

            if let navController = selectedViewController as? UINavigationController {
                let deleteBinVC = DeleteBinViewController()
                
                if let context = currentMonthContext {
                    deleteBinVC.filterMonthKey = context.key
                    deleteBinVC.filterMonthTitle = context.title
                }
                navController.pushViewController(deleteBinVC, animated: true)
            }
        }
    }

}

extension MainTabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        setBinButtonPlacement(.standard)
        customTapHandler = nil
        currentMonthContext = nil
        binButton.setMode(.count(deleteBinStore.count))
        updateVisibility(immediate: true)
    }

    func navigationController(
        _ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool
    ) {
        isTransitioning = animated
        updateVisibility(immediate: true)
        // A screen that uses a slot sets it again once it's on top
        setBinButtonPlacement(.standard)

        if viewController is DeleteBinViewController {
            // Save the current mode before morphing to wide
            savedMode = binButton.currentMode
            morphButtonToWide()
            binButton.setWideTitle(Strings.deleteAll, enabled: deleteBinStore.count > 0)
        }
    }

    func navigationController(
        _ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool
    ) {
        isTransitioning = false

        if !(viewController is DeleteBinViewController)
            && !(viewController is SimilarPhotosViewController) {
            morphButtonToCompact()
        }

        updateVisibility()
    }

    private func morphButtonToWide() {
        binButtonLeadingConstraint?.isActive = true
        binButtonTrailingConstraint?.isActive = true

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8) {
            self.view.layoutIfNeeded()
        }

        binButton.morphToWide(animated: true)
    }

    @objc private func handleDeleteBinEditStateChange(_ notification: Notification) {
        guard case .wide = binButton.currentMode else { return }
        guard let userInfo = notification.userInfo,
            let isEditMode = userInfo["isEditMode"] as? Bool,
            let selectedCount = userInfo["selectedCount"] as? Int
        else { return }

        isDeleteBinEditing = isEditMode
        if isEditMode {
            // Deactivate leading first, then activate width
            binButtonLeadingConstraint?.isActive = false
            binButtonTrailingConstraint?.isActive = true
            binButtonFixedWidthConstraint?.constant = editModeHalfWidth
            binButtonFixedWidthConstraint?.isActive = true
            binButton.setWideTitle(Strings.delete, enabled: selectedCount > 0)
        } else {
            // Deactivate width BEFORE activating leading to avoid conflict
            binButtonFixedWidthConstraint?.isActive = false
            binButtonLeadingConstraint?.isActive = true
            binButtonTrailingConstraint?.isActive = true
            binButton.setWideTitle(Strings.deleteAll, enabled: true)
        }

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
            self.view.layoutIfNeeded()
        }
    }

    /// Half of the width the button is laid out in (content guide on iOS 26+,
    /// which excludes vertical bars on iPhone Duo).
    private var editModeHalfWidth: CGFloat {
        var availableWidth = view.bounds.width
        if #available(iOS 26.0, *) {
            availableWidth = contentLayoutGuide.layoutFrame.width
        }
        return (availableWidth / 2) - (GeneralConstants.EdgePadding.medium * 1.5)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if binButtonFixedWidthConstraint?.isActive == true, isDeleteBinEditing {
            binButtonFixedWidthConstraint?.constant = editModeHalfWidth
        }
        updateWideBinButtonForFold()

        // In a screen's slot the button follows that screen's row
        guard !isBinButtonInSlot else { return }

        // mode/sidebar.preferredPlacement don't give tab bar behavior. need calculation
        if let aboveTabBar = binButtonAboveTabBarConstraint,
            let alignedWithTabBar = binButtonAlignedWithTabBarConstraint
        {
            // 6pt next to the rail on either side. Across from a trailing rail the wide button
            // keeps clear of the device corner; across from a leading rail (Split View, left
            // half) it keeps the standard padding.
            let railEdge = DuoLayout.railEdge(self, in: view)
            let tabBarIsVertical = railEdge != nil
            let medium = GeneralConstants.EdgePadding.medium
            let nextToRail = DuoLayout.RailPadding.nextToRail
            binButtonTrailingConstraint?.constant = railEdge == .trailing ? -nextToRail : -medium
            switch railEdge {
            case nil: binButtonLeadingConstraint?.constant = medium
            case .trailing: binButtonLeadingConstraint?.constant = DuoLayout.RailPadding.cornerClearance
            case .leading: binButtonLeadingConstraint?.constant = nextToRail
            }
            if tabBarIsVertical {
                aboveTabBar.isActive = false
                alignedWithTabBar.isActive = true
            } else {
                alignedWithTabBar.isActive = false
                aboveTabBar.isActive = true
            }
        }
    }

    /// iPhone Duo book pose: the full-width "Delete All" button would sit in the fold,
    /// so it keeps to the trailing side of the fold (edit mode is already two halves).
    private func updateWideBinButtonForFold() {
        guard case .wide = binButton.currentMode, !isDeleteBinEditing, !isBinButtonInSlot,
              let fixedWidth = binButtonFixedWidthConstraint else { return }

        let fold = FoldRegion.activeFold(in: view)
        if FoldRegion.pose(for: fold) == .book, let fold = fold {
            let width = binButton.frame.maxX - fold.maxX - GeneralConstants.EdgePadding.medium
            guard width > 0 else { return }
            binButtonLeadingConstraint?.isActive = false
            if fixedWidth.constant != width { fixedWidth.constant = width }
            fixedWidth.isActive = true
        } else if fixedWidth.isActive {
            fixedWidth.isActive = false
            binButtonLeadingConstraint?.isActive = true
        }
    }

    private func morphButtonToCompact() {
        isDeleteBinEditing = false
        // In a screen's slot the slot keeps its frame; only the content changes
        if !isBinButtonInSlot {
            binButtonLeadingConstraint?.isActive = false
            binButtonTrailingConstraint?.isActive = true
            binButtonFixedWidthConstraint?.isActive = false
        }

        if let saved = savedMode {
            binButton.setMode(saved)
            savedMode = nil
        } else {
            let count = deleteBinStore.count
            binButton.morphToCompact(count: count, animated: true)
        }

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8) {
            self.view.layoutIfNeeded()
        }
    }
}

// MARK: - FloatingBinButtonController

extension MainTabBarController: FloatingBinButtonController {
    func configureBinButton(
        mode: FloatingBinButton.DisplayMode,
        monthKey: String?,
        monthTitle: String?,
        tapHandler: (() -> Void)?
    ) {
        if let key = monthKey, let title = monthTitle {
            currentMonthContext = (key: key, title: title)
        } else {
            currentMonthContext = nil
        }

        customTapHandler = tapHandler

        // If transitioning from wide to non-wide, morph layout back
        if case .wide = binButton.currentMode, mode != .wide {
            savedMode = nil
            morphButtonToCompact()
            binButton.setMode(mode)
            return
        }

        binButton.setMode(mode)
    }

    func configureWideBinButton(
        title: String,
        monthKey: String?,
        monthTitle: String?,
        tapHandler: (() -> Void)?
    ) {
        if let key = monthKey, let title = monthTitle {
            currentMonthContext = (key: key, title: title)
        } else {
            currentMonthContext = nil
        }
        customTapHandler = tapHandler

        if binButton.currentMode != .wide {
            savedMode = binButton.currentMode
        }
        morphButtonToWide()
        binButton.setWideTitle(title, enabled: true)
    }

    func showBinButton() {
        binButton.alpha = 1
    }

    func setBinButtonPlacement(_ placement: BinButtonPlacement) {
        guard placement != binButtonPlacement else { return }
        let wasInSlot = isBinButtonInSlot
        binButtonPlacement = placement

        switch placement {
        case .slot(let windowRect):
            let rect = view.convert(windowRect, from: nil)
            if !wasInSlot {
                // Deactivate every standard constraint before the slot's
                NSLayoutConstraint.deactivate([
                    binButtonLeadingConstraint, binButtonTrailingConstraint, binButtonFixedWidthConstraint,
                    binButtonStandardBottomConstraint, binButtonAboveTabBarConstraint,
                    binButtonAlignedWithTabBarConstraint
                ].compactMap { $0 })
            }
            // The rect is in physical coordinates; the constraint measures from the leading edge
            let isLeftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
            binSlotLeadingConstraint?.constant = isLeftToRight ? rect.minX : view.bounds.width - rect.maxX
            binSlotWidthConstraint?.constant = rect.width
            binSlotBottomConstraint?.constant = rect.maxY
            if !wasInSlot {
                NSLayoutConstraint.activate([
                    binSlotLeadingConstraint, binSlotWidthConstraint, binSlotBottomConstraint
                ].compactMap { $0 })
            }

        case .standard:
            NSLayoutConstraint.deactivate([
                binSlotLeadingConstraint, binSlotWidthConstraint, binSlotBottomConstraint
            ].compactMap { $0 })
            binButtonTrailingConstraint?.isActive = true
            if case .wide = binButton.currentMode {
                binButtonLeadingConstraint?.isActive = true
            }
            if binButtonAboveTabBarConstraint != nil {
                // iOS 26: viewDidLayoutSubviews picks the bottom for the tab bar's shape
                binButtonAboveTabBarConstraint?.isActive = true
                view.setNeedsLayout()
            } else {
                binButtonStandardBottomConstraint?.isActive = true
            }
        }

        if wasInSlot != isBinButtonInSlot, view.window != nil {
            UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
        }
    }

    func hideBinButton() {
        customTapHandler = nil
        currentMonthContext = nil

        if case .wide = binButton.currentMode {
            savedMode = nil
            morphButtonToCompact()
        } else {
            binButton.setMode(.count(deleteBinStore.count))
        }

        updateVisibility(immediate: true)
    }
}

#if DEBUG
    extension MainTabBarController {
        private static var devMenuEnabled = true

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake, Self.devMenuEnabled else { return }
            showDevMenu()
        }

        private func showDevMenu() {
            let service = ReminderNotificationService.shared
            let sheet = UIAlertController(title: "Dev Menu", message: nil, preferredStyle: .actionSheet)

            sheet.addAction(
                UIAlertAction(title: "5sn sonra bildirim gonder", style: .default) { [weak self] _ in
                    service.scheduleTestNotification(afterSeconds: 5)
                    self?.showConfirmation("Bildirim 5sn sonra gelecek")
                })

            sheet.addAction(
                UIAlertAction(title: "60sn sonra bildirim gonder", style: .default) { [weak self] _ in
                    service.scheduleTestNotification(afterSeconds: 60)
                    self?.showConfirmation("Bildirim 60sn sonra gelecek")
                })

            sheet.addAction(
                UIAlertAction(title: "Bekleyen bildirim sayisi", style: .default) { [weak self] _ in
                    service.getPendingCount { count in
                        self?.showConfirmation("Bekleyen bildirim: \(count)")
                    }
                })

            sheet.addAction(
                UIAlertAction(title: "Dev Menu Kapat", style: .destructive) { [weak self] _ in
                    Self.devMenuEnabled = false
                    self?.showConfirmation("Dev Menu kapatildi.\nYeniden baslatinca acilir.")
                })

            sheet.addAction(UIAlertAction(title: "Iptal", style: .cancel))

            present(sheet, animated: true)
        }

        private func showConfirmation(_ message: String) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Tamam", style: .default))
            present(alert, animated: true)
        }
    }
#endif

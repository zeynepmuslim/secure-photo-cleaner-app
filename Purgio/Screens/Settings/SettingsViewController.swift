//
//  SettingsViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import MessageUI
import SwiftUI
import UIKit

// MARK: - Strings
private enum Strings {
    static let navTitle = NSLocalizedString("settings.navTitle", comment: "Settings navigation title")

    static let yourImpact = NSLocalizedString("settings.yourImpact", comment: "Your impact section header")
    static let storageAnalysis = NSLocalizedString("settings.storageAnalysis", comment: "Storage analysis section header")
    static let storageCardTitle = NSLocalizedString(
        "settings.storageCardTitle", comment: "Storage card title in the upright split layout")
    static let photoManagement = NSLocalizedString("settings.photoManagement", comment: "Photo management section header")
    static let features = NSLocalizedString("settings.features", comment: "Features section header")
    static let transparencySafety = NSLocalizedString("settings.transparencySafety", comment: "Transparency & safety section header")
    static let about = NSLocalizedString("settings.about", comment: "About section header")
    static let version = NSLocalizedString("settings.version", comment: "App version label")
    static let madeBy = NSLocalizedString("settings.madeBy", comment: "Made by credit")

    static let internetTitle = NSLocalizedString("settings.internetTitle", comment: "Internet access toggle title")
    static let internetSubtitle = NSLocalizedString("settings.internetSubtitle", comment: "Internet access toggle subtitle")
    static let skipICloudTitle = NSLocalizedString("settings.skipICloudTitle", comment: "Skip iCloud photos toggle title")
    static let skipICloudSubtitle = NSLocalizedString("settings.skipICloudSubtitle", comment: "Skip iCloud photos toggle subtitle")
    static let internetSubtitleShort = NSLocalizedString(
        "settings.internetSubtitleShort", comment: "Internet access row subtitle in the split layout")
    static let skipICloudSubtitleShort = NSLocalizedString(
        "settings.skipICloudSubtitleShort", comment: "Skip iCloud photos row subtitle in the split layout")
    static let remindersTitle = NSLocalizedString("settings.remindersTitle", comment: "Reminders section title")

    static let privacyTitle = NSLocalizedString("settings.privacyTitle", comment: "Privacy first info title")
    static let privacyText = NSLocalizedString("settings.privacyText", comment: "Privacy first explanation")
    static let storeTitle = NSLocalizedString("settings.storeTitle", comment: "Store feature info title")
    static let storeText = NSLocalizedString("settings.storeText", comment: "Store feature explanation")
    static let transparencyTitle = NSLocalizedString("settings.transparencyTitle", comment: "Transparency info title")
    static let transparencyText = NSLocalizedString("settings.transparencyText", comment: "Transparency explanation")
    static let viewSourceCode = NSLocalizedString("settings.viewSourceCode", comment: "View source code button")

    static let internetOnMessage = NSLocalizedString("settings.internetOnMessage", comment: "Internet enabled toast")
    static let internetOffMessage = NSLocalizedString("settings.internetOffMessage", comment: "Internet disabled toast")
    static let skipICloudOnMessage = NSLocalizedString("settings.skipICloudOnMessage", comment: "Skip iCloud enabled toast")
    static let skipICloudOffMessage = NSLocalizedString("settings.skipICloudOffMessage", comment: "Skip iCloud disabled toast")

    static let notificationsDisabled = NSLocalizedString("settings.notificationsDisabled", comment: "Notifications disabled alert title")
    static let notificationsDeniedMessage = NSLocalizedString("settings.notificationsDeniedMessage", comment: "Notifications denied message")
    static let ok = CommonStrings.ok

    static let schedule = NSLocalizedString("settings.schedule", comment: "Schedule label")
    static let daily = NSLocalizedString("settings.daily", comment: "Daily frequency option")
    static let weekly = NSLocalizedString("settings.weekly", comment: "Weekly frequency option")
    static let monthly = NSLocalizedString("settings.monthly", comment: "Monthly frequency option")

    static let support = NSLocalizedString("settings.support", comment: "Support section header")
    static let supportTitle = NSLocalizedString("settings.supportTitle", comment: "Support project title")
    static let supportText = NSLocalizedString("settings.supportText", comment: "Support project description")
    static let supportButton = NSLocalizedString("settings.supportButton", comment: "Support on Patreon button")

    static let languageTitle = NSLocalizedString("settings.languageTitle", comment: "App language title")
    static let languageSubtitle = NSLocalizedString("settings.languageSubtitle", comment: "Available languages subtitle")
    static let languageButton = NSLocalizedString("settings.languageButton", comment: "Change language in settings button")

    static let rateAppTitle = NSLocalizedString("settings.rateAppTitle", comment: "Rate the app row title")
    static let giveFeedbackTitle = NSLocalizedString("settings.giveFeedbackTitle", comment: "Give feedback row title")
    static let feedbackSubject = NSLocalizedString("settings.feedbackSubject", comment: "Pre-filled feedback email subject")
    static let mailUnavailableTitle = NSLocalizedString("settings.mailUnavailableTitle", comment: "Mail not configured alert title")
    static let mailUnavailableMessage = NSLocalizedString("settings.mailUnavailableMessage", comment: "Mail not configured alert message")
}

final class SettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private var duoEdges: [DuoEdgeConstraints] = []

    // iPhone Duo inner display: two panes split at the fold, each scrolling on its own.
    // Sideways (vertical fold) the first pane is the left column; upright (horizontal fold)
    // it's the raised half and the second pane the base.
    private let sectionSpacing: CGFloat = 24
    /// Split layouts: between groups, and from a section label to its card
    private let splitGroupSpacing: CGFloat = 20
    private let splitLabelSpacing: CGFloat = 8
    /// The one scroll view's content starts this far below the bar
    private let contentStackTopPadding: CGFloat = 24
    /// Storage's share of the raised half's Storage | Support row (upright inner display)
    private let storageRowWidthRatio: CGFloat = 0.47
    private let splitContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    private let firstPaneScrollView = SettingsViewController.makePaneScrollView()
    private let secondPaneScrollView = SettingsViewController.makePaneScrollView()
    private let firstPaneStack = SettingsViewController.makePaneStack()
    private let secondPaneStack = SettingsViewController.makePaneStack()
    private let impactTilesView = ImpactTilesView()
    private let supportCardView = SettingsSupportCardView()
    private var hasBuiltContent = false
    /// How Settings is laid out right now, re-read on every layout pass (updateFoldSplit)
    private enum SplitLayout {
        /// One column: iPhones, the cover display, Split View
        case single
        /// Held sideways: two columns, each scrolling on its own
        case sideBySide
        /// Upright, fully open: one scroll view, the raised half reaching the gap, then the base
        case uprightScroll
        /// Upright, partly folded (table pose): the raised half stands still, only the base scrolls
        case uprightPanes
    }
    private var splitLayout: SplitLayout = .single
    private var firstPaneEdgeToVerticalFold: NSLayoutConstraint?
    private var paneGapAcrossVerticalFold: NSLayoutConstraint?
    /// Upright and fully open: the raised half (tiles, then Storage | Support) at the top of
    /// the one scroll view, at least as tall as the space above the fold so the base starts
    /// below it before scrolling
    private let raisedHalfStack = SettingsViewController.makePaneStack()
    private var raisedHalfMinHeight: NSLayoutConstraint?
    /// Upright and partly folded: the raised half is the first pane, ending at the gap and
    /// standing still; only the base (the second pane) scrolls
    private var firstPaneEdgeToHorizontalFold: NSLayoutConstraint?
    private var sideBySidePaneConstraints: [NSLayoutConstraint] = []
    private var stackedPaneConstraints: [NSLayoutConstraint] = []
    /// Upright and partly folded: the base's top inset; the gap at the fold is part of the
    /// base's scroll view, so its rows blur away under it
    private var stackedGap: CGFloat = 0
    /// Upright and partly folded: the base's scroll view starts this far below the raised half, so rows
    /// scrolling up are cut off before they reach its cards
    private let baseTopClearance = GeneralConstants.EdgePadding.small
    private let baseTopBlurView: ProgressiveBlurView = {
        let view = ProgressiveBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    private var baseTopBlurHeight: NSLayoutConstraint?
    /// Upright, folding or unfolding: the old layout's snapshot, cross-dissolved away once the
    /// new one is laid out (viewDidLayoutSubviews)
    private var layoutSwitchSnapshot: UIView?
    private let layoutSwitchDuration: TimeInterval = 0.3
    /// Upright, folding or unfolding: the layout to switch to once the current one has
    /// scrolled back to its top, so the cross-dissolve runs between two resting layouts
    private var pendingSplitLayout: SplitLayout?
    private let scrollToTopDuration: TimeInterval = 0.25
    private var firstPaneFillHeight: NSLayoutConstraint?

    // Upright raised half: Storage | Support in one row, the two cards ending together
    private let storageSupportRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.spacing = GeneralConstants.EdgePadding.small
        return stack
    }()
    private let storageRowColumn = SettingsViewController.makePaneStack()
    private let supportRowColumn = SettingsViewController.makePaneStack()
    /// Grows with the row so Storage ends level with Support. StorageAnalysisView keeps its
    /// own height inside it: stretching it would stretch one of its rows.
    private let storageCardSlot: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        // Matches StorageAnalysisView's own corners so the two read as one card
        view.layer.cornerRadius = 14
        view.layer.cornerCurve = .continuous
        return view
    }()

    // Split layouts: the settings groups as grouped-list rows (board S3t)
    private let photoGroup = SettingsGroupView()
    private let internetRow = SettingsGroupRowView()
    private let skipICloudRow = SettingsGroupRowView()
    private let featuresGroup = SettingsGroupView()
    private let remindersRow = SettingsGroupRowView()
    private let scheduleMenuRow = SettingsGroupRowView()
    private let languageRow = SettingsGroupRowView()
    private let storeRow = SettingsGroupRowView()
    private let transparencyGroup = SettingsGroupView()
    private let privacyRow = SettingsGroupRowView()
    private let sourceCodeRow = SettingsGroupRowView()
    private let aboutGroup = SettingsGroupView()
    private let versionRow = SettingsGroupRowView()

    /// The Storage card's title (upright split layout), built like the support card's title row
    private let storageTitleRow: UIStackView = {
        let iconView = UIImageView()
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        iconView.image = UIImage(systemName: "internaldrive.fill", withConfiguration: symbolConfig)
        iconView.tintColor = .systemBlue
        iconView.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24)
        ])

        let titleLabel = UILabel()
        titleLabel.text = Strings.storageCardTitle
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let statsSectionLabel = UILabel()
    private let impactStatsView = ImpactStatsView()

    private let storageSectionLabel = UILabel()
    private let storageAnalysisView = StorageAnalysisView()

    private let photoSectionLabel = UILabel()
    private let internetToggleContainer = UIView()
    private let internetLabelsStack = UIStackView()
    private let internetTitleLabel = UILabel()
    private let internetSubtitleLabel = UILabel()
    private let internetSwitch = UISwitch()
    private let skipICloudToggleContainer = UIView()
    private let skipICloudLabelsStack = UIStackView()
    private let skipICloudTitleLabel = UILabel()
    private let skipICloudSubtitleLabel = UILabel()
    private let skipICloudSwitch = UISwitch()
    private let remindersToggleContainer = UIView()
    private let remindersContentStack = UIStackView()
    private let remindersTopRow = UIView()
    private let remindersTitleLabel = UILabel()
    private let remindersSwitch = UISwitch()
    private let scheduleRow = UIView()
    private let scheduleSeparator = UIView()
    private let scheduleTitleLabel = UILabel()
    private let scheduleButton = UIButton(type: .system)

    private let privacyCard = SettingsInfoCardView()
    private let storeSectionLabel = UILabel()
    private let storeCard = SettingsInfoCardView()
    private let transparencySectionLabel = UILabel()
    private let transparencyCard = SettingsInfoCardView()
    private let supportSectionLabel = UILabel()
    private let supportCard = SettingsInfoCardView()
    private let languageCard = SettingsInfoCardView()

    private let helpLinksContainer = UIView()
    private let helpLinksStack = UIStackView()
    private let rateAppRow = SettingsLinkRowView()
    private let helpLinksSeparatorContainer = UIView()
    private let helpLinksSeparator = UIView()
    private let feedbackRow = SettingsLinkRowView()

    private let aboutSectionLabel = UILabel()
    private let madeByLabel = UILabel()
    private let versionLabel = UILabel()

    private let settingsStore = SettingsStore.shared
    private let statsStore = StatsStore.shared
    private let storedStore = WillBeStoredStore.shared
    private let storageManager = StorageAnalysisManager.shared

    private let feedbackEmail = "zeynep.muslim@icloud.com"
    private let appStoreID = "6762494793"

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground
        title = Strings.navTitle

        let tipJarButton = UIBarButtonItem(
            image: UIImage(systemName: "heart.fill"),
            style: .plain,
            target: self,
            action: #selector(tipJarBarButtonTapped)
        )
        tipJarButton.title = Strings.supportTitle
        tipJarButton.tintColor = .tipJarRed100
        tipJarButton.accessibilityLabel = Strings.supportTitle
        navigationItem.rightBarButtonItem = tipJarButton

        setupUI()
        setupConstraint()
        setupNotifications()
        updateInternetToggleState()
        updateSkipICloudToggleState()
        updateRemindersToggleState()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        impactStatsView.update(stats: statsStore, storedCount: storedStore.count)
        impactTilesView.configure(
            spaceSaved: statsStore.formattedSpaceSaved(), storedCount: storedStore.count,
            reviewedCount: statsStore.totalReviewed)
        storageAnalysisView.update(with: storageManager.currentState)
        updateInternetToggleState()
        updateSkipICloudToggleState()
        updateRemindersToggleState()
    }

    /// The bar can take its height after the first layout (iPhone Duo held sideways); nothing
    /// is pinned to the safe area's top, so lay out again for the panes' top insets
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateFoldSplit()
        let railEdge = DuoLayout.railEdge(tabBarController, in: view)
        duoEdges.forEach { $0.update(railEdge: railEdge) }
        updatePaneInsets(railEdge: railEdge)
        updateCardCorners(isVerticalRail: railEdge != nil)
        finishLayoutSwitch()
    }

    /// The moved views land in their new places at once (inside the fold's animation they'd
    /// slide in from their old superviews), then the old layout's snapshot fades away
    private func finishLayoutSwitch() {
        guard let snapshot = layoutSwitchSnapshot else { return }
        layoutSwitchSnapshot = nil
        UIView.performWithoutAnimation {
            view.layoutIfNeeded()
            // The new layout starts at its top, like the old one it fades from
            scrollViews(for: splitLayout).forEach { $0.contentOffset.y = -$0.adjustedContentInset.top }
        }
        snapshot.isUserInteractionEnabled = false
        snapshot.frame = view.bounds
        view.addSubview(snapshot)
        UIView.animate(withDuration: layoutSwitchDuration, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            snapshot.alpha = 0
        } completion: { _ in
            snapshot.removeFromSuperview()
        }
    }

    /// As on Home: on the vertical rail, the card in the device's bottom corner follows its
    /// curve. Held sideways that's the support card, which ends on the baseline at the
    /// leading edge; upright it ends at the fold and keeps the standard corners.
    private func updateCardCorners(isVerticalRail: Bool) {
        let followsCorner = isVerticalRail && splitLayout == .sideBySide
        // The card's frame is only final once the pane's stack is laid out
        if followsCorner { firstPaneScrollView.layoutIfNeeded() }
        supportCardView.updateCardCorners(followingDeviceCorner: followsCorner)
    }

    /// The panes run from the device's top edge: a pane starting there gets the top safe area
    /// (the bar) as its top inset, so it rests below the bar and scrolls on up to the edge.
    /// They reach the view's bottom edge; a pane ending there gets a bottom inset so its
    /// last card rests on Home's baseline (on the rail 20pt above the view's bottom, otherwise
    /// 16pt above the safe area). Upright and partly folded the raised half ends at the gap
    /// instead, starting as far below the bar as the single column does, and the base's top
    /// inset is the gap.
    private func updatePaneInsets(railEdge: DuoLayout.RailEdge?) {
        guard splitLayout == .sideBySide || splitLayout == .uprightPanes else { return }
        let baselineInset = railEdge != nil
            ? DuoLayout.RailPadding.bottom
            : view.safeAreaInsets.bottom + GeneralConstants.EdgePadding.medium
        let stackTopPadding = GeneralConstants.EdgePadding.medium
        let barInset = view.safeAreaInsets.top
        let isStacked = splitLayout == .uprightPanes
        let firstPaneInsets = isStacked
            ? UIEdgeInsets(top: barInset + contentStackTopPadding - stackTopPadding, left: 0, bottom: 0, right: 0)
            : UIEdgeInsets(top: barInset, left: 0, bottom: baselineInset, right: 0)
        let secondPaneInsets = UIEdgeInsets(
            top: isStacked ? max(0, stackedGap - baseTopClearance - stackTopPadding) : barInset,
            left: 0, bottom: baselineInset, right: 0)
        setInsets(firstPaneInsets, of: firstPaneScrollView)
        setInsets(secondPaneInsets, of: secondPaneScrollView)
        updateBaseTopBlur()
        setConstant(-(stackTopPadding + firstPaneInsets.top + firstPaneInsets.bottom), of: firstPaneFillHeight)
    }

    private func setInsets(_ insets: UIEdgeInsets, of scrollView: UIScrollView) {
        guard scrollView.contentInset != insets else { return }
        // A pane resting at its top keeps resting there when the top inset changes
        let wasAtTop = scrollView.contentOffset.y <= -scrollView.contentInset.top + 0.5
        scrollView.contentInset = insets
        scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(
            top: insets.top, left: 0, bottom: insets.bottom, right: 0)
        if wasAtTop {
            scrollView.contentOffset.y = -insets.top
        }
    }

    // MARK: - Fold Split

    /// Splits Settings at the fold, read on every layout pass: two columns, each scrolling on
    /// its own, at a vertical fold (the inner display held sideways); at a horizontal one (the
    /// inner display upright) the raised half above the fold and the base below it, all in one
    /// scroll view while fully open, and with only the base scrolling while partly folded.
    /// The fold counts while fully open too, so unfolding sideways moves nothing but the gap.
    /// Everything else keeps the single column.
    private func updateFoldSplit() {
        var fold = FoldRegion.splittingFold(in: view)
        // A horizontal fold only splits the inner display (regular width); compact keeps one column
        if let candidate = fold, candidate.width >= candidate.height,
           traitCollection.horizontalSizeClass != .regular {
            fold = nil
        }
        let isFolded = FoldRegion.activeFold(in: view) != nil
        let layout: SplitLayout
        if let fold = fold {
            // Side by side across a vertical fold, stacked across a horizontal one
            layout = fold.height > fold.width ? .sideBySide : (isFolded ? .uprightPanes : .uprightScroll)
        } else {
            layout = .single
        }
        if !hasBuiltContent || layout != splitLayout {
            // Folding or unfolding upright swaps the scrolling: scroll back to the top first,
            // then cross-dissolve to the new layout. Rotating has the system's own transition.
            let uprightLayouts: [SplitLayout] = [.uprightScroll, .uprightPanes]
            let isUprightSwitch = hasBuiltContent && view.window != nil
                && uprightLayouts.contains(splitLayout) && uprightLayouts.contains(layout)
            if isUprightSwitch && !isAtTop(splitLayout) {
                // Meanwhile the current layout keeps following the fold
                if pendingSplitLayout != layout {
                    pendingSplitLayout = layout
                    scrollToTopThenSwitch()
                }
            } else {
                pendingSplitLayout = nil
                if isUprightSwitch, layoutSwitchSnapshot == nil {
                    layoutSwitchSnapshot = view.snapshotView(afterScreenUpdates: false)
                }
                UIView.performWithoutAnimation { rebuildContent(for: layout) }
            }
        } else {
            // The pose went back before the scroll finished
            pendingSplitLayout = nil
        }

        guard let fold = fold else {
            // The hidden panes keep a sane split so their constraints never conflict
            setConstant(view.bounds.midX, of: firstPaneEdgeToVerticalFold)
            setConstant(view.bounds.midY, of: firstPaneEdgeToHorizontalFold)
            setConstant(0, of: raisedHalfMinHeight)
            return
        }
        let isSideBySide = splitLayout == .sideBySide
        let foldStart = isSideBySide ? fold.minX : fold.minY
        let foldLength = isSideBySide ? fold.width : fold.height
        // Fully open, the halves keep the section spacing, centered on the fold line.
        // Folded, they clear the whole region.
        let gap = isFolded ? max(sectionSpacing, foldLength) : sectionSpacing
        let firstPaneEdge = foldStart + foldLength / 2 - gap / 2
        switch splitLayout {
        case .sideBySide:
            setConstant(firstPaneEdge, of: firstPaneEdgeToVerticalFold)
            setConstant(gap, of: paneGapAcrossVerticalFold)
            setConstant(0, of: raisedHalfMinHeight)
        case .uprightScroll:
            // Before scrolling the content starts below the bar (the adjusted inset) plus the
            // stack's top padding; the raised half reaches from there to the gap
            let contentTop = scrollView.adjustedContentInset.top + contentStackTopPadding
            setConstant(max(0, firstPaneEdge - contentTop), of: raisedHalfMinHeight)
            if contentStack.customSpacing(after: raisedHalfStack) != gap {
                contentStack.setCustomSpacing(gap, after: raisedHalfStack)
            }
        case .uprightPanes:
            // The raised half ends at the gap; the base starts a clearance below it, its top inset
            // (updatePaneInsets) keeping the first row a gap away, and the blur fills the gap
            setConstant(firstPaneEdge, of: firstPaneEdgeToHorizontalFold)
            setConstant(0, of: raisedHalfMinHeight)
            stackedGap = gap
            setConstant(max(0, gap - baseTopClearance), of: baseTopBlurHeight)
        case .single:
            break
        }
    }

    /// The scroll views a layout shows
    private func scrollViews(for layout: SplitLayout) -> [UIScrollView] {
        switch layout {
        case .single, .uprightScroll: return [scrollView]
        case .sideBySide, .uprightPanes: return [firstPaneScrollView, secondPaneScrollView]
        }
    }

    private func isAtTop(_ layout: SplitLayout) -> Bool {
        scrollViews(for: layout).allSatisfy { $0.contentOffset.y <= -$0.adjustedContentInset.top + 0.5 }
    }

    /// Scrolls the current layout back to its top, then lays out again: the next pass finds it
    /// resting and switches to the pending layout with the cross-dissolve
    private func scrollToTopThenSwitch() {
        scrollViews(for: splitLayout).forEach { $0.setContentOffset($0.contentOffset, animated: false) }
        UIView.animate(withDuration: scrollToTopDuration, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.scrollViews(for: self.splitLayout).forEach { $0.contentOffset.y = -$0.adjustedContentInset.top }
        } completion: { [weak self] _ in
            guard let self = self, self.pendingSplitLayout != nil else { return }
            self.pendingSplitLayout = nil
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
    }

    private func setConstant(_ constant: CGFloat, of constraint: NSLayoutConstraint?) {
        guard let constraint = constraint, constraint.constant != constant else { return }
        constraint.constant = constant
    }

    /// Moves the same views between the single column, the raised half and the two fold panes.
    private func rebuildContent(for layout: SplitLayout) {
        hasBuiltContent = true
        splitLayout = layout
        let stacks = [contentStack, raisedHalfStack, firstPaneStack, secondPaneStack, storageRowColumn, supportRowColumn]
        for stack in stacks {
            // Spacing set for one layout must not carry over to the next
            stack.arrangedSubviews.forEach {
                stack.setCustomSpacing(UIStackView.spacingUseDefault, after: $0)
                $0.removeFromSuperview()
            }
        }
        contentStack.spacing = sectionSpacing
        // Inside the slot it's a plain subview, not an arranged one
        storageAnalysisView.removeFromSuperview()

        // Sideways and upright partly folded use the two panes, side by side or stacked;
        // the single column and upright fully open the one scroll view
        let usesPanes = layout == .sideBySide || layout == .uprightPanes
        let isStacked = layout == .uprightPanes
        scrollView.isHidden = usesPanes
        splitContainerView.isHidden = !usesPanes
        baseTopBlurView.isHidden = !isStacked
        NSLayoutConstraint.deactivate(isStacked ? sideBySidePaneConstraints : stackedPaneConstraints)
        NSLayoutConstraint.activate(isStacked ? stackedPaneConstraints : sideBySidePaneConstraints)

        // Photo Management, Features, Transparency & Safety: the same in every layout
        let settingsGroups: [UIView] = [
            photoSectionLabel, internetToggleContainer, skipICloudToggleContainer,
            storeSectionLabel, remindersToggleContainer, languageCard, storeCard,
            transparencySectionLabel, privacyCard, transparencyCard
        ]
        let aboutViews: [UIView] = [aboutSectionLabel, versionLabel, madeByLabel]
        // The split layouts' grouped rows (board S3t)
        let splitSettingsGroups: [UIView] = [
            photoSectionLabel, photoGroup, storeSectionLabel, featuresGroup,
            transparencySectionLabel, transparencyGroup, aboutSectionLabel, aboutGroup, madeByLabel
        ]

        let fill = { (stack: UIStackView, views: [UIView]) in
            views.forEach { stack.addArrangedSubview($0) }
            stack.setCustomSpacing(12, after: self.aboutSectionLabel)
            stack.setCustomSpacing(4, after: self.versionLabel)
        }
        // The board's denser rhythm: a label sits close to its card, groups keep a wider gap
        let applySplitSpacing = { (stack: UIStackView) in
            stack.spacing = self.splitGroupSpacing
            [self.photoSectionLabel, self.storeSectionLabel, self.transparencySectionLabel,
             self.aboutSectionLabel, self.supportSectionLabel, self.storageSectionLabel, self.aboutGroup]
                .forEach { stack.setCustomSpacing(self.splitLabelSpacing, after: $0) }
            stack.setCustomSpacing(GeneralConstants.EdgePadding.small, after: self.impactTilesView)
            // Sideways the support card follows Storage directly, as the cards do upright
            stack.setCustomSpacing(GeneralConstants.EdgePadding.small, after: self.storageAnalysisView)
        }

        switch layout {
        case .uprightScroll, .uprightPanes:
            // The raised half: the tiles, then Storage | Support side by side, without their labels
            // Under the card's title row, like the support card's; the content fills the
            // height the row gives the card
            storageCardSlot.addSubview(storageAnalysisView)
            NSLayoutConstraint.activate([
                storageAnalysisView.topAnchor.constraint(equalTo: storageTitleRow.bottomAnchor),
                storageAnalysisView.leadingAnchor.constraint(equalTo: storageCardSlot.leadingAnchor),
                storageAnalysisView.trailingAnchor.constraint(equalTo: storageCardSlot.trailingAnchor),
                storageAnalysisView.bottomAnchor.constraint(lessThanOrEqualTo: storageCardSlot.bottomAnchor)
            ])
            // No section labels: the cards carry their own titles, and the raised half needs
            // the height to fit above the fold
            fill(storageRowColumn, [storageCardSlot])
            fill(supportRowColumn, [supportCardView])
            if isStacked {
                // The raised half in the first pane, the base's grouped rows in the second
                fill(firstPaneStack, [impactTilesView, storageSupportRow])
                fill(secondPaneStack, splitSettingsGroups)
                [storageRowColumn, supportRowColumn, firstPaneStack, secondPaneStack].forEach(applySplitSpacing)
            } else {
                // One scroll view: the raised half, then the base's grouped rows
                fill(raisedHalfStack, [impactTilesView, storageSupportRow])
                fill(contentStack, [raisedHalfStack] + splitSettingsGroups)
                [storageRowColumn, supportRowColumn, raisedHalfStack, contentStack].forEach(applySplitSpacing)
            }
        case .sideBySide:
            // No Support label: the card carries its own title, as upright
            fill(firstPaneStack, [impactTilesView, storageAnalysisView, supportCardView])
            fill(secondPaneStack, splitSettingsGroups)
            [firstPaneStack, secondPaneStack].forEach(applySplitSpacing)
        case .single:
            fill(contentStack,
                 [statsSectionLabel, impactStatsView, storageSectionLabel, storageAnalysisView]
                 + settingsGroups
                 + [supportSectionLabel, supportCard, helpLinksContainer]
                 + aboutViews)
        }
    }

    private static func makePaneScrollView() -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        // The column already starts below the bar and ends on the baseline; a system inset
        // would leave the last card short of it
        scrollView.contentInsetAdjustmentBehavior = .never
        if #available(iOS 26.0, *) {
            // Rows scrolling under the title fade out progressively, not under a solid band
            scrollView.topEdgeEffect.style = .soft
        }
        return scrollView
    }

    private static func makePaneStack() -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        updateButtonIcons()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidStart,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidFetchBasicInfo,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidComplete,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storageAnalysisStateChanged),
            name: .storageAnalysisDidFail,
            object: nil
        )
    }

    @objc private func storageAnalysisStateChanged() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.storageAnalysisView.update(with: self.storageManager.currentState)
        }
    }

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .mainBackground
        view.addSubview(scrollView)

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = sectionSpacing
        scrollView.addSubview(contentStack)

        view.addSubview(splitContainerView)
        splitContainerView.addSubview(firstPaneScrollView)
        splitContainerView.addSubview(secondPaneScrollView)
        firstPaneScrollView.addSubview(firstPaneStack)
        // It fits its height exactly, so it only scrolls when the content can't fit
        firstPaneScrollView.alwaysBounceVertical = false
        secondPaneScrollView.addSubview(secondPaneStack)
        // Upright the base's scroll position drives the blur over its top edge
        secondPaneScrollView.delegate = self
        splitContainerView.addSubview(baseTopBlurView)
        storageSupportRow.addArrangedSubview(storageRowColumn)
        storageSupportRow.addArrangedSubview(supportRowColumn)
        storageCardSlot.translatesAutoresizingMaskIntoConstraints = false
        storageCardSlot.addSubview(storageTitleRow)
        NSLayoutConstraint.activate([
            storageTitleRow.topAnchor.constraint(equalTo: storageCardSlot.topAnchor, constant: 16),
            storageTitleRow.leadingAnchor.constraint(equalTo: storageCardSlot.leadingAnchor, constant: 18),
            storageTitleRow.trailingAnchor.constraint(lessThanOrEqualTo: storageCardSlot.trailingAnchor, constant: -18)
        ])

        supportCardView.configure(
            title: Strings.supportTitle, message: Strings.supportText, tipTitle: Strings.supportButton,
            rateTitle: Strings.rateAppTitle, feedbackTitle: Strings.giveFeedbackTitle)
        supportCardView.onTip = { [weak self] in self?.tipJarBarButtonTapped() }
        supportCardView.onRate = { [weak self] in self?.rateAppTapped() }
        supportCardView.onFeedback = { [weak self] in self?.feedbackTapped() }

        statsSectionLabel.text = Strings.yourImpact
        statsSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        statsSectionLabel.textColor = .systemGray


        storageSectionLabel.text = Strings.storageAnalysis
        storageSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        storageSectionLabel.textColor = .systemGray

        storageAnalysisView.translatesAutoresizingMaskIntoConstraints = false
        storageAnalysisView.onRefreshTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            self?.storageManager.startAnalysis()
        }
        storageAnalysisView.update(with: storageManager.currentState)

        photoSectionLabel.text = Strings.photoManagement
        photoSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        photoSectionLabel.textColor = .systemGray

        internetToggleContainer.backgroundColor = .cardBackground
        internetToggleContainer.layer.cornerRadius = 14
        internetToggleContainer.layer.cornerCurve = .continuous
        internetToggleContainer.layer.borderWidth = 0
        internetToggleContainer.layer.borderColor = UIColor.separator.cgColor
        internetToggleContainer.translatesAutoresizingMaskIntoConstraints = false

        internetLabelsStack.axis = .vertical
        internetLabelsStack.spacing = 4
        internetLabelsStack.translatesAutoresizingMaskIntoConstraints = false

        internetTitleLabel.text = Strings.internetTitle
        internetTitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        internetTitleLabel.textColor = .label
        internetLabelsStack.addArrangedSubview(internetTitleLabel)

        internetSubtitleLabel.text = Strings.internetSubtitle
        internetSubtitleLabel.font = .systemFont(ofSize: 14)
        internetSubtitleLabel.textColor = .systemGray
        internetSubtitleLabel.numberOfLines = 0
        internetLabelsStack.addArrangedSubview(internetSubtitleLabel)

        internetSwitch.translatesAutoresizingMaskIntoConstraints = false
        internetSwitch.addTarget(self, action: #selector(internetSwitchChanged), for: .valueChanged)

        internetToggleContainer.addSubview(internetLabelsStack)
        internetToggleContainer.addSubview(internetSwitch)

        skipICloudToggleContainer.backgroundColor = .cardBackground
        skipICloudToggleContainer.layer.cornerRadius = 14
        skipICloudToggleContainer.layer.cornerCurve = .continuous
        skipICloudToggleContainer.layer.borderWidth = 0
        skipICloudToggleContainer.layer.borderColor = UIColor.separator.cgColor
        skipICloudToggleContainer.translatesAutoresizingMaskIntoConstraints = false

        skipICloudLabelsStack.axis = .vertical
        skipICloudLabelsStack.spacing = 4
        skipICloudLabelsStack.translatesAutoresizingMaskIntoConstraints = false

        skipICloudTitleLabel.text = Strings.skipICloudTitle
        skipICloudTitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        skipICloudTitleLabel.textColor = .label
        skipICloudLabelsStack.addArrangedSubview(skipICloudTitleLabel)

        skipICloudSubtitleLabel.text = Strings.skipICloudSubtitle
        skipICloudSubtitleLabel.font = .systemFont(ofSize: 14)
        skipICloudSubtitleLabel.textColor = .systemGray
        skipICloudSubtitleLabel.numberOfLines = 0
        skipICloudLabelsStack.addArrangedSubview(skipICloudSubtitleLabel)

        skipICloudSwitch.translatesAutoresizingMaskIntoConstraints = false
        skipICloudSwitch.addTarget(self, action: #selector(skipICloudSwitchChanged), for: .valueChanged)

        skipICloudToggleContainer.addSubview(skipICloudLabelsStack)
        skipICloudToggleContainer.addSubview(skipICloudSwitch)

        remindersToggleContainer.backgroundColor = .cardBackground
        remindersToggleContainer.layer.cornerRadius = 14
        remindersToggleContainer.layer.cornerCurve = .continuous
        remindersToggleContainer.layer.borderWidth = 0
        remindersToggleContainer.layer.borderColor = UIColor.separator.cgColor
        remindersToggleContainer.clipsToBounds = true
        remindersToggleContainer.translatesAutoresizingMaskIntoConstraints = false

        remindersContentStack.axis = .vertical
        remindersContentStack.spacing = 0
        remindersContentStack.translatesAutoresizingMaskIntoConstraints = false

        remindersTopRow.translatesAutoresizingMaskIntoConstraints = false

        remindersTitleLabel.text = Strings.remindersTitle
        remindersTitleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        remindersTitleLabel.textColor = .label
        remindersTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        remindersSwitch.translatesAutoresizingMaskIntoConstraints = false
        remindersSwitch.addTarget(self, action: #selector(remindersSwitchChanged), for: .valueChanged)

        remindersTopRow.addSubview(remindersTitleLabel)
        remindersTopRow.addSubview(remindersSwitch)

        scheduleSeparator.backgroundColor = .separator
        scheduleSeparator.translatesAutoresizingMaskIntoConstraints = false

        scheduleRow.translatesAutoresizingMaskIntoConstraints = false
        scheduleRow.isHidden = !settingsStore.remindersEnabled
        scheduleRow.alpha = settingsStore.remindersEnabled ? 1 : 0

        scheduleTitleLabel.text = Strings.schedule
        scheduleTitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        scheduleTitleLabel.textColor = .secondaryLabel
        scheduleTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        scheduleButton.translatesAutoresizingMaskIntoConstraints = false
        scheduleButton.showsMenuAsPrimaryAction = true
        scheduleButton.contentHorizontalAlignment = .trailing
        updateScheduleMenu()

        scheduleRow.addSubview(scheduleSeparator)
        scheduleRow.addSubview(scheduleTitleLabel)
        scheduleRow.addSubview(scheduleButton)

        remindersContentStack.addArrangedSubview(remindersTopRow)
        remindersContentStack.addArrangedSubview(scheduleRow)
        remindersToggleContainer.addSubview(remindersContentStack)

        privacyCard.configure(with: SettingsInfoCardConfig(
            iconName: "lock.shield", iconColor: .systemBlue,
            title: Strings.privacyTitle, subtitle: Strings.privacyText
        ))
        privacyCard.onCardTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            let sheet = AskPermissionBoardingViewController(status: .noAction)
            self?.present(sheet, animated: true)
        }

        storeCard.configure(with: SettingsInfoCardConfig(
            iconName: "archivebox.fill", iconColor: ThemeManager.Colors.statusYellow,
            title: Strings.storeTitle, subtitle: Strings.storeText
        ))
        storeCard.onCardTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            let tutorial = StoreTutorialSheetViewController()
            self?.present(tutorial, animated: true)
        }

        transparencyCard.configure(with: SettingsInfoCardConfig(
            iconName: "checkmark.shield.fill", iconColor: .systemGreen,
            title: Strings.transparencyTitle, subtitle: Strings.transparencyText,
            themeColor: .systemGreen,
            buttonTitle: Strings.viewSourceCode, buttonImageName: "GitHub_Invertocat"
        ))
        transparencyCard.onButtonTapped = { [weak self] in
            self?.openSourceCode()
            HapticFeedbackManager.shared.impact(intensity: .light)
        }

        supportCard.configure(with: SettingsInfoCardConfig(
            iconName: "heart.fill", iconColor: .tipJarRed100,
            title: Strings.supportTitle, subtitle: Strings.supportText,
            themeColor: .tipJarRed100,
            buttonTitle: Strings.supportButton, buttonIconName: "sparkles"
        ))
        supportCard.onButtonTapped = { [weak self] in
            self?.tipJarBarButtonTapped()
        }

        languageCard.configure(with: SettingsInfoCardConfig(
            iconName: "globe", iconColor: .systemBlue,
            title: Strings.languageTitle, subtitle: Strings.languageSubtitle,
            themeColor: .systemBlue,
            buttonTitle: Strings.languageButton, buttonIconName: "gear"
        ))
        languageCard.onButtonTapped = { [weak self] in
            HapticFeedbackManager.shared.impact(intensity: .light)
            self?.openAppSettings()
        }

        setupGroupRows()

        helpLinksContainer.backgroundColor = .cardBackground
        helpLinksContainer.layer.cornerRadius = 14
        helpLinksContainer.layer.cornerCurve = .continuous
        helpLinksContainer.clipsToBounds = true
        helpLinksContainer.translatesAutoresizingMaskIntoConstraints = false

        helpLinksStack.axis = .vertical
        helpLinksStack.spacing = 0
        helpLinksStack.translatesAutoresizingMaskIntoConstraints = false

        rateAppRow.configure(
            iconName: "star.fill",
            iconColor: .systemYellow,
            title: Strings.rateAppTitle
        )
        rateAppRow.onTap = { [weak self] in self?.rateAppTapped() }

        feedbackRow.configure(
            iconName: "envelope.fill",
            iconColor: .systemBlue,
            title: Strings.giveFeedbackTitle
        )
        feedbackRow.onTap = { [weak self] in self?.feedbackTapped() }

        helpLinksSeparatorContainer.translatesAutoresizingMaskIntoConstraints = false
        helpLinksSeparator.backgroundColor = .separator
        helpLinksSeparator.translatesAutoresizingMaskIntoConstraints = false
        helpLinksSeparatorContainer.addSubview(helpLinksSeparator)

        helpLinksStack.addArrangedSubview(rateAppRow)
        helpLinksStack.addArrangedSubview(helpLinksSeparatorContainer)
        helpLinksStack.addArrangedSubview(feedbackRow)
        helpLinksContainer.addSubview(helpLinksStack)

        storeSectionLabel.text = Strings.features
        storeSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        storeSectionLabel.textColor = .systemGray




        transparencySectionLabel.text = Strings.transparencySafety
        transparencySectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        transparencySectionLabel.textColor = .systemGray



        supportSectionLabel.text = Strings.support
        supportSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        supportSectionLabel.textColor = .systemGray



        aboutSectionLabel.text = Strings.about
        aboutSectionLabel.font = ThemeManager.Fonts.titleFont(size: 12, weight: .semibold)
        aboutSectionLabel.textColor = .systemGray

        versionLabel.text = "\(Strings.version) \(appVersion)"
        versionLabel.font = .systemFont(ofSize: 15, weight: .bold)
        versionLabel.textColor = .systemGray2

        madeByLabel.text = Strings.madeBy
        madeByLabel.font = .systemFont(ofSize: 13)
        madeByLabel.textColor = .systemGray2
    }

    /// The split layouts' grouped rows (board S3t). They drive the same settings as the
    /// single column's cards; the update methods keep both in sync.
    private func setupGroupRows() {
        internetRow.configure(
            iconName: "wifi", iconColor: .systemBlue, title: Strings.internetTitle,
            subtitle: Strings.internetSubtitleShort, accessory: .toggle)
        internetRow.onToggle = { [weak self] isOn in self?.setInternetAccess(isOn) }
        skipICloudRow.configure(
            iconName: "icloud.slash", iconColor: .systemGray, title: Strings.skipICloudTitle,
            subtitle: Strings.skipICloudSubtitleShort, accessory: .toggle)
        skipICloudRow.onToggle = { [weak self] isOn in self?.setSkipICloud(isOn) }
        photoGroup.configure(rows: [internetRow, skipICloudRow])

        remindersRow.configure(
            iconName: "bell.fill", iconColor: .systemRed, title: Strings.remindersTitle, accessory: .toggle)
        remindersRow.onToggle = { [weak self] isOn in self?.setReminders(isOn) }
        scheduleMenuRow.configure(
            iconName: "calendar", iconColor: .systemOrange, title: Strings.schedule, accessory: .text(""))
        languageRow.configure(
            iconName: "globe", iconColor: .systemBlue, title: Strings.languageTitle,
            subtitle: Strings.languageSubtitle, accessory: .value(currentLanguageName, .external))
        languageRow.onTap = { [weak self] in self?.openAppSettings() }
        storeRow.configure(
            iconName: "archivebox.fill", iconColor: ThemeManager.Colors.statusYellow, title: Strings.storeTitle,
            subtitle: Strings.storeText, accessory: .navigation(.sheet))
        storeRow.onTap = { [weak self] in
            self?.present(StoreTutorialSheetViewController(), animated: true)
        }
        featuresGroup.configure(rows: [remindersRow, scheduleMenuRow, languageRow, storeRow])

        privacyRow.configure(
            iconName: "lock.shield", iconColor: .systemBlue, title: Strings.privacyTitle,
            subtitle: Strings.privacyText, accessory: .navigation(.sheet))
        privacyRow.onTap = { [weak self] in
            self?.present(AskPermissionBoardingViewController(status: .noAction), animated: true)
        }
        sourceCodeRow.configure(
            iconName: "checkmark.shield.fill", iconColor: .systemGreen, title: Strings.transparencyTitle,
            subtitle: Strings.transparencyText, accessory: .navigation(.external))
        sourceCodeRow.accessibilityHint = Strings.viewSourceCode
        sourceCodeRow.onTap = { [weak self] in self?.openSourceCode() }
        transparencyGroup.configure(rows: [privacyRow, sourceCodeRow])

        versionRow.configure(
            iconName: "info.circle", iconColor: .systemGray, title: Strings.version, accessory: .text(appVersion))
        aboutGroup.configure(rows: [versionRow])
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }

    /// The language the app runs in, named in that language's own locale ("English", "Türkçe")
    private var currentLanguageName: String {
        guard let code = Bundle.main.preferredLocalizations.first else { return "" }
        let locale = Locale(identifier: code)
        return locale.localizedString(forLanguageCode: code)?.capitalized(with: locale) ?? code
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openSourceCode() {
        guard let url = URL(string: "https://github.com/zeynepmuslim/secure-photo-cleaner-app") else { return }
        UIApplication.shared.open(url)
    }

    private func setupConstraint() {
        // The vertical scroll view spans the full width; its content's sides follow the safe
        // area and, on iPhone Duo, Home's vertical-rail padding.
        let contentEdges = DuoEdgeConstraints(
            item: contentStack, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content)
        // The fold panes run to the view's bottom edge; their content insets stop the last card
        // on Home's bottom baseline (updatePaneInsets)
        let splitEdges = DuoEdgeConstraints(
            item: splitContainerView, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content)
        duoEdges = [contentEdges, splitEdges]
        NSLayoutConstraint.activate(contentEdges.initialConstraints + splitEdges.initialConstraints)

        // The fold edges move to the fold's position on every layout pass (updateFoldSplit)
        let first = firstPaneScrollView
        let second = secondPaneScrollView
        let container = splitContainerView
        let edgeToVerticalFold = first.trailingAnchor.constraint(equalTo: view.leadingAnchor)
        let gapAcrossVerticalFold = second.leadingAnchor.constraint(
            equalTo: first.trailingAnchor, constant: sectionSpacing)
        firstPaneEdgeToVerticalFold = edgeToVerticalFold
        paneGapAcrossVerticalFold = gapAcrossVerticalFold

        // Sideways: two columns, each the container's full height
        let sideBySideConstraints = [
            first.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            first.topAnchor.constraint(equalTo: container.topAnchor),
            first.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            edgeToVerticalFold,
            gapAcrossVerticalFold,
            second.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            second.topAnchor.constraint(equalTo: container.topAnchor),
            second.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ]
        // Upright: the raised half above the gap, the base from the gap to the bottom. The gap
        // is the base's top inset, under the blur, so its rows blur away as they scroll up.
        let edgeToHorizontalFold = first.bottomAnchor.constraint(equalTo: view.topAnchor)
        firstPaneEdgeToHorizontalFold = edgeToHorizontalFold
        let blurHeight = baseTopBlurView.heightAnchor.constraint(equalToConstant: 0)
        baseTopBlurHeight = blurHeight
        let stackedConstraints = [
            first.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            first.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            first.topAnchor.constraint(equalTo: container.topAnchor),
            edgeToHorizontalFold,
            second.topAnchor.constraint(equalTo: first.bottomAnchor, constant: baseTopClearance),
            second.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            second.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            second.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ]
        sideBySidePaneConstraints = sideBySideConstraints
        stackedPaneConstraints = stackedConstraints
        // Upright the raised half reaches the gap (its minimum height fully open, its pane
        // partly folded); the Storage | Support row takes the extra height (lower hugging than
        // the tiles), so the two cards end together at the gap
        let raisedHalfHeight = raisedHalfStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
        raisedHalfMinHeight = raisedHalfHeight
        storageSupportRow.setContentHuggingPriority(.defaultLow - 2, for: .vertical)

        // The first pane fits its height exactly: the stack is at least the pane's height minus
        // its insets, and the lowest-hugging view (the impact tiles sideways, the Storage |
        // Support row upright) takes up the difference
        let firstPaneFill = firstPaneStack.heightAnchor.constraint(
            greaterThanOrEqualTo: firstPaneScrollView.frameLayoutGuide.heightAnchor,
            constant: -GeneralConstants.EdgePadding.medium)
        firstPaneFillHeight = firstPaneFill
        impactTilesView.setContentHuggingPriority(.defaultLow - 1, for: .vertical)

        var columnConstraints: [NSLayoutConstraint] = [
            // From the device's top edge, so rows scroll on up to it instead of being cut off
            // below the bar; the panes' top insets (updatePaneInsets) start them below the bar
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            firstPaneFill,
            raisedHalfHeight,
            // Upright and partly folded, over the base's top edge (the gap)
            baseTopBlurView.topAnchor.constraint(equalTo: second.topAnchor),
            baseTopBlurView.leadingAnchor.constraint(equalTo: second.leadingAnchor),
            baseTopBlurView.trailingAnchor.constraint(equalTo: second.trailingAnchor),
            blurHeight,
            storageRowColumn.widthAnchor.constraint(
                equalTo: storageSupportRow.widthAnchor, multiplier: storageRowWidthRatio)
        ]
        for (columnScrollView, stack) in [(firstPaneScrollView, firstPaneStack),
                                          (secondPaneScrollView, secondPaneStack)] {
            columnConstraints += [
                columnScrollView.contentLayoutGuide.widthAnchor.constraint(
                    equalTo: columnScrollView.frameLayoutGuide.widthAnchor),

                stack.topAnchor.constraint(
                    equalTo: columnScrollView.contentLayoutGuide.topAnchor, constant: GeneralConstants.EdgePadding.medium),
                // The last card rests on the baseline when scrolled to the end
                stack.bottomAnchor.constraint(equalTo: columnScrollView.contentLayoutGuide.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: columnScrollView.frameLayoutGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: columnScrollView.frameLayoutGuide.trailingAnchor)
            ]
        }
        NSLayoutConstraint.activate(columnConstraints + sideBySideConstraints)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            contentStack.topAnchor.constraint(
                equalTo: scrollView.contentLayoutGuide.topAnchor, constant: contentStackTopPadding),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),

            internetToggleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 70),

            internetLabelsStack.topAnchor.constraint(equalTo: internetToggleContainer.topAnchor, constant: 16),
            internetLabelsStack.leadingAnchor.constraint(equalTo: internetToggleContainer.leadingAnchor, constant: 18),
            internetLabelsStack.bottomAnchor.constraint(equalTo: internetToggleContainer.bottomAnchor, constant: -16),
            internetLabelsStack.trailingAnchor.constraint(equalTo: internetSwitch.leadingAnchor, constant: -16),

            internetSwitch.centerYAnchor.constraint(equalTo: internetToggleContainer.centerYAnchor),
            internetSwitch.trailingAnchor.constraint(equalTo: internetToggleContainer.trailingAnchor, constant: -18),

            skipICloudToggleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 70),

            skipICloudLabelsStack.topAnchor.constraint(equalTo: skipICloudToggleContainer.topAnchor, constant: 16),
            skipICloudLabelsStack.leadingAnchor.constraint(
                equalTo: skipICloudToggleContainer.leadingAnchor, constant: 18),
            skipICloudLabelsStack.bottomAnchor.constraint(
                equalTo: skipICloudToggleContainer.bottomAnchor, constant: -16),
            skipICloudLabelsStack.trailingAnchor.constraint(equalTo: skipICloudSwitch.leadingAnchor, constant: -16),

            skipICloudSwitch.centerYAnchor.constraint(equalTo: skipICloudToggleContainer.centerYAnchor),
            skipICloudSwitch.trailingAnchor.constraint(
                equalTo: skipICloudToggleContainer.trailingAnchor, constant: -18),

            remindersContentStack.topAnchor.constraint(equalTo: remindersToggleContainer.topAnchor),
            remindersContentStack.leadingAnchor.constraint(equalTo: remindersToggleContainer.leadingAnchor),
            remindersContentStack.trailingAnchor.constraint(equalTo: remindersToggleContainer.trailingAnchor),
            remindersContentStack.bottomAnchor.constraint(equalTo: remindersToggleContainer.bottomAnchor),

            remindersTitleLabel.topAnchor.constraint(equalTo: remindersTopRow.topAnchor, constant: 16),
            remindersTitleLabel.leadingAnchor.constraint(equalTo: remindersTopRow.leadingAnchor, constant: 18),
            remindersTitleLabel.bottomAnchor.constraint(equalTo: remindersTopRow.bottomAnchor, constant: -16),
            remindersTitleLabel.trailingAnchor.constraint(equalTo: remindersSwitch.leadingAnchor, constant: -16),

            remindersSwitch.centerYAnchor.constraint(equalTo: remindersTopRow.centerYAnchor),
            remindersSwitch.trailingAnchor.constraint(equalTo: remindersTopRow.trailingAnchor, constant: -18),

            scheduleSeparator.topAnchor.constraint(equalTo: scheduleRow.topAnchor),
            scheduleSeparator.leadingAnchor.constraint(equalTo: scheduleRow.leadingAnchor, constant: 18),
            scheduleSeparator.trailingAnchor.constraint(equalTo: scheduleRow.trailingAnchor, constant: -18),
            scheduleSeparator.heightAnchor.constraint(equalToConstant: 0.5),

            scheduleTitleLabel.topAnchor.constraint(equalTo: scheduleSeparator.bottomAnchor, constant: 12),
            scheduleTitleLabel.leadingAnchor.constraint(equalTo: scheduleRow.leadingAnchor, constant: 18),
            scheduleTitleLabel.bottomAnchor.constraint(equalTo: scheduleRow.bottomAnchor, constant: -12),

            scheduleButton.centerYAnchor.constraint(equalTo: scheduleTitleLabel.centerYAnchor),
            scheduleButton.trailingAnchor.constraint(equalTo: scheduleRow.trailingAnchor, constant: -18),
            scheduleButton.leadingAnchor.constraint(
                greaterThanOrEqualTo: scheduleTitleLabel.trailingAnchor, constant: 12),

            helpLinksStack.topAnchor.constraint(equalTo: helpLinksContainer.topAnchor),
            helpLinksStack.leadingAnchor.constraint(equalTo: helpLinksContainer.leadingAnchor),
            helpLinksStack.trailingAnchor.constraint(equalTo: helpLinksContainer.trailingAnchor),
            helpLinksStack.bottomAnchor.constraint(equalTo: helpLinksContainer.bottomAnchor),

            helpLinksSeparatorContainer.heightAnchor.constraint(equalToConstant: 0.5),
            helpLinksSeparator.topAnchor.constraint(equalTo: helpLinksSeparatorContainer.topAnchor),
            helpLinksSeparator.bottomAnchor.constraint(equalTo: helpLinksSeparatorContainer.bottomAnchor),
            helpLinksSeparator.leadingAnchor.constraint(
                equalTo: helpLinksSeparatorContainer.leadingAnchor, constant: 18),
            helpLinksSeparator.trailingAnchor.constraint(
                equalTo: helpLinksSeparatorContainer.trailingAnchor, constant: -18),

        ])
    }

    func scrollToInternetToggle() {
        // Split at the fold the grouped rows show the toggle: in the second pane sideways (the
        // trailing column) and upright partly folded (the base), else in the one scroll view
        let usesPanes = splitLayout == .sideBySide || splitLayout == .uprightPanes
        let scrollView = usesPanes ? secondPaneScrollView : self.scrollView
        let target: UIView = splitLayout != .single ? photoGroup : internetToggleContainer
        let targetY = target.convert(CGPoint.zero, to: scrollView).y
        let topInset = scrollView.adjustedContentInset.top
        let maxOffsetY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom
        let offsetY = min(max(targetY - topInset - 16, -topInset), max(maxOffsetY, -topInset))
        scrollView.setContentOffset(CGPoint(x: 0, y: offsetY), animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.highlight(target)
        }
    }

    private func highlight(_ target: UIView) {
        HapticFeedbackManager.shared.impact(intensity: .medium)

        let originalColor = target.backgroundColor
        let originalBorderWidth = target.layer.borderWidth
        let originalBorderColor = target.layer.borderColor

        UIView.animate(withDuration: 0.3, animations: {
            target.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
            target.layer.borderWidth = 2
            target.layer.borderColor = UIColor.systemBlue.cgColor
        }) { _ in
            UIView.animate(withDuration: 0.8, delay: 0.6) {
                target.backgroundColor = originalColor
                target.layer.borderWidth = originalBorderWidth
                target.layer.borderColor = originalBorderColor
            }
        }
    }

    @objc private func internetSwitchChanged() {
        setInternetAccess(internetSwitch.isOn)
    }

    @objc private func skipICloudSwitchChanged() {
        setSkipICloud(skipICloudSwitch.isOn)
    }

    // The card switches (single column) and the group rows (split layouts) share these paths

    private func setInternetAccess(_ isOn: Bool) {
        settingsStore.allowInternetAccess = isOn
        HapticFeedbackManager.shared.impact(intensity: .medium)
        updateInternetToggleState()
    }

    private func setSkipICloud(_ isOn: Bool) {
        settingsStore.skipICloudPhotos = isOn
        HapticFeedbackManager.shared.impact(intensity: .medium)
        updateSkipICloudToggleState()
    }

    @objc private func tipJarBarButtonTapped() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        let tipJar = TipJarViewController()
        tipJar.onRestoredInternet = { [weak self] in
            self?.showInternetRestoredConfirmation()
        }
        present(tipJar, animated: true)
    }

    @objc private func remindersSwitchChanged() {
        setReminders(remindersSwitch.isOn)
    }

    private func setReminders(_ isOn: Bool) {
        if isOn {
            ReminderNotificationService.shared.requestAuthorization { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.settingsStore.remindersEnabled = true
                    ReminderNotificationService.shared.scheduleReminders()
                } else {
                    self.settingsStore.remindersEnabled = false
                    self.showRemindersDeniedAlert()
                }

                self.updateRemindersToggleState()
            }
        } else {
            settingsStore.remindersEnabled = false
            ReminderNotificationService.shared.syncScheduleIfNeeded()

            updateRemindersToggleState()
        }

        HapticFeedbackManager.shared.impact(intensity: .medium)
    }

    private func updateButtonIcons() {
        transparencyCard.refreshButtonIcon()
    }

    private func updateInternetToggleState() {
        let isOn = settingsStore.allowInternetAccess
        if internetSwitch.isOn != isOn { internetSwitch.isOn = isOn }
        internetRow.setToggleOn(isOn)

        internetSwitch.onTintColor = .systemGreen

        updateSkipICloudVisibility()
    }

    private func updateSkipICloudToggleState() {
        let isOn = settingsStore.skipICloudPhotos
        if skipICloudSwitch.isOn != isOn { skipICloudSwitch.isOn = isOn }
        skipICloudRow.setToggleOn(isOn)

        skipICloudSwitch.onTintColor = .systemGreen

        updateSkipICloudVisibility()
    }

    private func updateSkipICloudVisibility() {
        let shouldShow = !settingsStore.allowInternetAccess
        let shouldHide = !shouldShow
        photoGroup.setRow(skipICloudRow, hidden: shouldHide, animated: hasBuiltContent)
        guard skipICloudToggleContainer.isHidden != shouldHide else { return }
        UIView.animate(withDuration: 0.3) {
            self.skipICloudToggleContainer.isHidden = shouldHide
            self.skipICloudToggleContainer.alpha = shouldHide ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }

    private func updateRemindersToggleState() {
        let isOn = settingsStore.remindersEnabled
        if remindersSwitch.isOn != isOn { remindersSwitch.isOn = isOn }
        remindersRow.setToggleOn(isOn, animated: hasBuiltContent)

        remindersSwitch.onTintColor = .systemGreen

        updateSchedulePickerVisibility()
        updateScheduleMenu()
    }

    private func showRemindersDeniedAlert() {
        let alert = UIAlertController(
            title: Strings.notificationsDisabled,
            message: Strings.notificationsDeniedMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        present(alert, animated: true)
    }

    private func showInternetRestoredConfirmation() {
        let message = NSLocalizedString(
            "tipJar.internetRestored",
            comment: "Feedback when tip jar automatically turned internet access off"
        )
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }

    private func updateScheduleMenu() {
        let currentFrequency = settingsStore.reminderFrequency

        let dailyAction = UIAction(
            title: Strings.daily,
            state: currentFrequency == .daily ? .on : .off
        ) { [weak self] _ in
            self?.applySchedulePreset(.dailyEvening)
        }

        let weeklyAction = UIAction(
            title: Strings.weekly,
            state: currentFrequency == .weekly ? .on : .off
        ) { [weak self] _ in
            self?.applySchedulePreset(.weeklyEvening)
        }

        let monthlyAction = UIAction(
            title: Strings.monthly,
            state: currentFrequency == .monthly ? .on : .off
        ) { [weak self] _ in
            self?.applySchedulePreset(.monthlyFirstEvening)
        }

        let menu = UIMenu(children: [dailyAction, weeklyAction, monthlyAction])
        scheduleButton.menu = menu

        let title: String
        switch currentFrequency {
        case .daily: title = Strings.daily
        case .weekly: title = Strings.weekly
        case .monthly: title = Strings.monthly
        }
        scheduleButton.setTitle(title, for: .normal)
        scheduleMenuRow.setMenu(title: title, menu: menu)
    }

    private func applySchedulePreset(_ preset: SettingsStore.ReminderSchedulePreset) {
        settingsStore.applyReminderSchedule(preset)
        updateScheduleMenu()

        if settingsStore.remindersEnabled {
            ReminderNotificationService.shared.scheduleReminders()
        }

        HapticFeedbackManager.shared.impact(intensity: .light)
    }

    private func updateSchedulePickerVisibility() {
        let shouldShow = settingsStore.remindersEnabled
        let shouldHide = !shouldShow
        featuresGroup.setRow(scheduleMenuRow, hidden: shouldHide, animated: hasBuiltContent)
        guard scheduleRow.isHidden != shouldHide else { return }
        UIView.animate(withDuration: 0.3) {
            self.scheduleRow.isHidden = shouldHide
            self.scheduleRow.alpha = shouldHide ? 0 : 1
            self.view.layoutIfNeeded()
        }
    }

    private func rateAppTapped() {
        let urlString = "https://apps.apple.com/app/id\(appStoreID)?action=write-review"
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func feedbackEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let iosVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        return """


        ---
        App: Purgio \(appVersion)
        iOS: \(iosVersion) | Device: \(deviceModel)
        """
    }

    private func feedbackTapped() {
        if MFMailComposeViewController.canSendMail() {
            let composer = MFMailComposeViewController()
            composer.mailComposeDelegate = self
            composer.setToRecipients([feedbackEmail])
            composer.setSubject(Strings.feedbackSubject)
            composer.setMessageBody(feedbackEmailBody(), isHTML: false)
            present(composer, animated: true)
            return
        }

        let subject = Strings.feedbackSubject
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = feedbackEmailBody()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let mailto = URL(string: "mailto:\(feedbackEmail)?subject=\(subject)&body=\(body)"),
           UIApplication.shared.canOpenURL(mailto) {
            UIApplication.shared.open(mailto)
        } else {
            showMailUnavailableAlert()
        }
    }

    private func showMailUnavailableAlert() {
        let alert = UIAlertController(
            title: Strings.mailUnavailableTitle,
            message: Strings.mailUnavailableMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        present(alert, animated: true)
    }

}

// MARK: - UIScrollViewDelegate

extension SettingsViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === secondPaneScrollView else { return }
        updateBaseTopBlur()
    }

    /// Upright and partly folded: the blur over the gap shows only as far as the base's rows have scrolled under it
    private func updateBaseTopBlur() {
        guard splitLayout == .uprightPanes else { return }
        let scrolled = secondPaneScrollView.contentOffset.y + secondPaneScrollView.adjustedContentInset.top
        baseTopBlurView.setContentOverlap(scrolled)
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension SettingsViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
    }
}

@available(iOS 17.0, *)
#Preview {
    SettingsViewController()
}

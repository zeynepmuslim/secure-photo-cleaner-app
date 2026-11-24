//
//  UndoHistoryViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Photos
import SwiftUI
import UIKit

protocol UndoHistoryDelegate: AnyObject {
    func didPerformAction(_ actionType: UndoAction.ActionType, on action: UndoAction)
    func didUndoAll(_ actions: [UndoAction])
    func didUndoActions(_ actions: [UndoAction])
}

final class UndoHistoryViewController: UIViewController {

    weak var delegate: UndoHistoryDelegate?
    private let historyManager = UndoHistoryManager.shared
    private let imageManager = PHCachingImageManager()
    private var thumbnailSize: CGSize = .zero

    private var thumbnailCache: [String: UIImage] = [:]

    private var isEditMode = false

    private var keepButton: DynamicGlassButton!
    private var deleteButton: DynamicGlassButton!
    private var storeButton: DynamicGlassButton!
    private var undoButton: DynamicGlassButton!

    /// The selection toolbar's metrics; `shouldShowToolbarTitles` measures with the same values.
    private enum ToolbarStyle {
        static let titleSize: CGFloat = 13
        static let titledIconSize: CGFloat = 11
        static let iconOnlySize: CGFloat = 18
        static let sideInset: CGFloat = 10
        /// What a titled button's symbol takes, and DynamicGlassButton's gap to the title.
        static let titledIconWidth: CGFloat = 16
        static let imagePadding: CGFloat = 8
    }

    /// - Parameters:
    ///   - ink: the glyph color on the solid button (`UndoAction.ActionType.displayInk`).
    ///   - alwaysGlass: the glass look in light mode too, with the glyph in `color`.
    private func applyToolbarButtonStyle(
        _ button: DynamicGlassButton, title: String, systemImage: String, color: UIColor, ink: UIColor = .white,
        alwaysGlass: Bool = false, showTitles: Bool
    ) {
        // Light: solid color with the action's ink. Dark: the button is clear glass (iOS 26+) or a
        // soft tint (earlier) with the glyph in the action's color.
        let usesGlass = traitCollection.userInterfaceStyle == .dark || alwaysGlass
        let color = color.resolvedColor(with: traitCollection)
        let tintedBackground: UIColor
        if #available(iOS 26.0, *) {
            tintedBackground = color
        } else {
            tintedBackground = color.withAlphaComponent(0.18)
        }
        // Clear glass renders template symbols and titles in its own vibrant white, so in dark mode
        // the symbol is drawn in its color and the title carries its color as an attribute.
        let iconSize: CGFloat = showTitles ? ToolbarStyle.titledIconSize : ToolbarStyle.iconOnlySize
        let darkImage = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold))?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        let darkTitle = showTitles
            ? NSAttributedString(string: title, attributes: [
                .font: UIFont.systemFont(ofSize: ToolbarStyle.titleSize, weight: .semibold),
                .foregroundColor: color
            ])
            : nil
        button.configure(
            title: showTitles && !usesGlass ? title : nil,
            attributedTitle: usesGlass ? darkTitle : nil,
            image: usesGlass ? darkImage : nil,
            systemImage: usesGlass ? nil : systemImage,
            style: usesGlass ? .regular : .prominent,
            backgroundColor: usesGlass ? tintedBackground : color,
            foregroundColor: usesGlass ? color : ink,
            fontSize: ToolbarStyle.titleSize,
            iconSize: iconSize,
            contentInsets: NSDirectionalEdgeInsets(
                top: 12, leading: ToolbarStyle.sideInset, bottom: 12, trailing: ToolbarStyle.sideInset)
        )
        if showTitles {
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.7
        } else {
            button.accessibilityLabel = title
        }
    }

    // Re-applies title/icon-size styling whenever the view's width changes (see viewDidLayoutSubviews);
    // the initial width read in setupSelectionToolbar can be 0 before the sheet finishes presenting.
    private func updateSelectionToolbarButtonStyle(showTitles: Bool) {
        typealias ActionType = UndoAction.ActionType
        applyToolbarButtonStyle(
            keepButton, title: Strings.keep, systemImage: "checkmark.circle.fill",
            color: ActionType.keep.displayColor, ink: ActionType.keep.displayInk, showTitles: showTitles)
        applyToolbarButtonStyle(
            deleteButton, title: Strings.delete, systemImage: "trash.fill",
            color: ActionType.delete.displayColor, ink: ActionType.delete.displayInk, showTitles: showTitles)
        applyToolbarButtonStyle(
            storeButton, title: Strings.store, systemImage: "archivebox.fill",
            color: ActionType.store.displayColor, ink: ActionType.store.displayInk, showTitles: showTitles)
        // Glass in both modes, the glyph in `.label`: black in light mode, white in dark mode.
        applyToolbarButtonStyle(
            undoButton, title: Strings.undo, systemImage: "arrow.uturn.backward",
            color: .label, alwaysGlass: true, showTitles: showTitles)
    }

    private func setupSelectionToolbar() {
        view.addSubview(selectionToolbar)
        selectionToolbar.isHidden = true

        func createButton(action: Selector) -> DynamicGlassButton {
            let button = DynamicGlassButton()
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        keepButton = createButton(action: #selector(handleKeepSelected))
        deleteButton = createButton(action: #selector(handleDeleteSelected))
        storeButton = createButton(action: #selector(handleStoreSelected))
        undoButton = createButton(action: #selector(handleUndoSelected))
        // Icons only until the toolbar has a width to measure the titles against.
        updateSelectionToolbarButtonStyle(showTitles: false)

        selectionToolbar.addArrangedSubview(keepButton)
        selectionToolbar.addArrangedSubview(deleteButton)
        selectionToolbar.addArrangedSubview(storeButton)
        selectionToolbar.addArrangedSubview(undoButton)
    }

    private var actions: [UndoAction] {
        Array(historyManager.getCurrentSessionActions().reversed())
    }

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let statsLabel = UILabel()

    /// A solid capsule behind the counts, shown only while rows are scrolled under the header
    /// (iOS 26, where the list runs under it), so the counts stay readable over them.
    private let statsCapsuleView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray5
        view.layer.cornerCurve = .continuous
        view.alpha = 0
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tableView: UITableView = {
        let tabel = UITableView(frame: .zero, style: .insetGrouped)
        tabel.translatesAutoresizingMaskIntoConstraints = false
        tabel.register(UndoHistoryCell.self, forCellReuseIdentifier: "UndoHistoryCell")
        tabel.separatorStyle = .singleLine
        tabel.backgroundColor = .clear
        tabel.rowHeight = UITableView.automaticDimension
        tabel.estimatedRowHeight = 76
        tabel.sectionHeaderTopPadding = 0
        // The gap under the header is a content inset (`updateListInsets`), so rows scroll up
        // under the top edge's effect.
        tabel.contentInset.top = Layout.headerToList
        // No space of the grouped style's own under the last row: it rests on the bottom inset.
        tabel.sectionFooterHeight = .leastNonzeroMagnitude
        tabel.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        return tabel
    }()

    /// The sheet's own background, solid on every iOS version: plain `.systemGroupedBackground`
    /// turns into the iOS 26 sheet's glass; a color resolved from it per appearance stays solid.
    /// Resolved at the base level: a sheet's elevated dark gray is the rows' own `.cardBackground`,
    /// and the list's card would disappear into it.
    private static let sheetBackground = UIColor { traits in
        let base = UITraitCollection(traitsFrom: [traits, UITraitCollection(userInterfaceLevel: .base)])
        return UIColor.systemGroupedBackground.resolvedColor(with: base)
    }

    /// iOS 26 uses the scroll view's own edge effects (`setupNativeEdgeEffects`); earlier versions
    /// have none, so they keep the two `ProgressiveBlurView`s below.
    private var usesNativeEdgeEffects: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    /// Before iOS 26, under the header: rows scrolling up blur and fade into the sheet's background.
    private lazy var topBlurView: ProgressiveBlurView = {
        let view = ProgressiveBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.fadeColor = UndoHistoryViewController.sheetBackground
        return view
    }()

    /// Before iOS 26, at the bottom edge: rows scrolling down blur and fade out. In select mode it
    /// also covers the toolbar, so rows fade out under the buttons.
    private lazy var bottomBlurView: ProgressiveBlurView = {
        let view = ProgressiveBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.edge = .bottom
        view.fadeColor = UndoHistoryViewController.sheetBackground
        return view
    }()
    /// The bottom blur's top edge: a band over the bottom edge, or from above the toolbar.
    private var bottomBlurBandTopConstraint: NSLayoutConstraint?
    private var bottomBlurToolbarTopConstraint: NSLayoutConstraint?

    private let selectionToolbar: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
//        stack.backgroundColor = .red
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()

    /// The list runs to the sheet's bottom edge. The last row rests at the safe area's bottom; in
    /// select mode a bottom content inset rests it 12pt above the toolbar, and rows scroll on under
    /// the buttons. iOS 26: the list also runs under the header, and the system's soft edge effect
    /// shows under the header and the toolbar. Earlier: the list starts under the header and the
    /// two `ProgressiveBlurView`s fade its edges.
    private enum Layout {
        static let toolbarHeight = GeneralConstants.ButtonSize.mediumLarge
        static let toolbarClearance: CGFloat = 12
        /// From the stats label to the first row.
        static let headerToList: CGFloat = 12
        static let blurBandHeight: CGFloat = 28
        /// How far the counts' capsule reaches past the label.
        static let statsCapsuleOutset = CGSize(width: 8, height: 4)
    }

    private var appliedToolbarShowsTitles: Bool?
    private var didApplyInitialOffset = false

    /// Titles show only when the widest one fits a button of the toolbar's own width on one line
    /// (the Duo's cover display and most phones don't have the room; a wide sheet does).
    private var shouldShowToolbarTitles: Bool {
        let count = CGFloat(selectionToolbar.arrangedSubviews.count)
        let toolbarWidth = selectionToolbar.bounds.width
        guard count > 0, toolbarWidth > 0 else { return false }
        let buttonWidth = (toolbarWidth - selectionToolbar.spacing * (count - 1)) / count
        let font = UIFont.systemFont(ofSize: ToolbarStyle.titleSize, weight: .semibold)
        let widestTitle = Strings.toolbarTitles
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
        let needed = ToolbarStyle.sideInset * 2 + ToolbarStyle.titledIconWidth + ToolbarStyle.imagePadding + widestTitle
        return needed.rounded(.up) <= buttonWidth
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        calculateThumbnailSize()
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitDisplayScale.self]) { (self: UndoHistoryViewController, _) in
                self.calculateThumbnailSize()
            }
            // Attachments bake their colors, so rebuild the counts on an appearance change.
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: UndoHistoryViewController, _) in
                self.updateStatsLabel()
                self.restyleSelectionToolbar()
            }
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHistoryDidChange),
            name: .undoHistoryDidChange,
            object: nil
        )

        historyManager.removeActionsForDeletedAssets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateListInsets()
        // A top content inset set before the first layout doesn't move the content down by itself.
        if !didApplyInitialOffset, tableView.bounds.height > 0 {
            didApplyInitialOffset = true
            tableView.contentOffset.y = -tableView.adjustedContentInset.top
        }
        updateTopBlur()
        updateBottomBlur()
        statsCapsuleView.layer.cornerRadius = statsCapsuleView.bounds.height / 2
        updateStatsCapsule()

        // Re-evaluated on every size change (sheet resize, iPhone Duo open/close)
        let showTitles = shouldShowToolbarTitles
        guard appliedToolbarShowsTitles != showTitles else { return }
        appliedToolbarShowsTitles = showTitles
        updateSelectionToolbarButtonStyle(showTitles: showTitles)
    }

    // iOS 15/16 path for refreshing the counts' baked colors.
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateStatsLabel()
            restyleSelectionToolbar()
        }
    }

    /// The toolbar's look depends on the appearance (see applyToolbarButtonStyle).
    private func restyleSelectionToolbar() {
        updateSelectionToolbarButtonStyle(showTitles: appliedToolbarShowsTitles ?? shouldShowToolbarTitles)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleHistoryDidChange() {
        tableView.reloadData()
        updateStatsLabel()

        if historyManager.undoCount == 0 {
            dismiss(animated: true)
        }
    }

    private func setupUI() {
        // Solid at both detents and in both appearances; the nav bar on top of it is transparent.
        view.backgroundColor = Self.sheetBackground
        view.isOpaque = true
        applyTransparentNavigationBar()

        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        titleLabel.text = NSLocalizedString("undoHistory.reviewHistoryTitle", comment: "Undo history screen title")
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        updateStatsLabel()
        statsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statsLabel.textColor = .secondaryLabel
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(statsCapsuleView)
        headerView.addSubview(statsLabel)

        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(handleDone)
        )

        setupOptionsMenu()
        if !usesNativeEdgeEffects {
            view.addSubview(topBlurView)
            view.addSubview(bottomBlurView)
        }
        setupSelectionToolbar()
        view.bringSubviewToFront(selectionToolbar)
        if #available(iOS 26.0, *) {
            setupNativeEdgeEffects()
        }

        let padding = GeneralConstants.EdgePadding.medium
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: padding),
            headerView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -padding),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor),

            statsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            statsLabel.trailingAnchor.constraint(lessThanOrEqualTo: headerView.trailingAnchor),
            statsLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),

            statsCapsuleView.leadingAnchor.constraint(
                equalTo: statsLabel.leadingAnchor, constant: -Layout.statsCapsuleOutset.width),
            statsCapsuleView.trailingAnchor.constraint(
                equalTo: statsLabel.trailingAnchor, constant: Layout.statsCapsuleOutset.width),
            statsCapsuleView.topAnchor.constraint(
                equalTo: statsLabel.topAnchor, constant: -Layout.statsCapsuleOutset.height),
            statsCapsuleView.bottomAnchor.constraint(
                equalTo: statsLabel.bottomAnchor, constant: Layout.statsCapsuleOutset.height),

            // The 12pt gap to the first row is the table's top content inset (`Layout.headerToList`).
            // iOS 26: the table runs under the header, which shapes the system's edge effect.
            tableView.topAnchor.constraint(equalTo: usesNativeEdgeEffects ? view.topAnchor : headerView.bottomAnchor),
            // The inset-grouped table insets its card to the safe area itself; pinned to the safe
            // area guide it lost its side inset and corners on the Duo cover.
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            selectionToolbar.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: padding),
            selectionToolbar.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -padding),
            selectionToolbar.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor),
            selectionToolbar.heightAnchor.constraint(equalToConstant: Layout.toolbarHeight)
        ])

        guard !usesNativeEdgeEffects else { return }
        let bandTop = bottomBlurView.topAnchor.constraint(
            equalTo: safeArea.bottomAnchor, constant: -Layout.blurBandHeight)
        let toolbarTop = bottomBlurView.topAnchor.constraint(
            equalTo: selectionToolbar.topAnchor, constant: -(Layout.toolbarClearance + Layout.blurBandHeight))
        bottomBlurBandTopConstraint = bandTop
        bottomBlurToolbarTopConstraint = toolbarTop
        NSLayoutConstraint.activate([
            topBlurView.topAnchor.constraint(equalTo: tableView.topAnchor),
            topBlurView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            topBlurView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            topBlurView.heightAnchor.constraint(equalToConstant: GeneralConstants.EdgePadding.content),

            bandTop,
            bottomBlurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBlurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBlurView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// The first row rests `headerToList` under the header. The last row rests at the safe area's
    /// bottom (`EdgePadding.medium` above the edge on a home-button phone), or 12pt above the
    /// toolbar in select mode.
    private var listBottomInset: CGFloat {
        if isEditMode { return Layout.toolbarHeight + Layout.toolbarClearance }
        return view.safeAreaInsets.bottom == 0 ? GeneralConstants.EdgePadding.medium : 0
    }

    /// iOS 26: the header lies over the table, so its height is part of the top inset.
    private var listTopInset: CGFloat {
        usesNativeEdgeEffects ? headerView.bounds.height + Layout.headerToList : Layout.headerToList
    }

    private func updateListInsets() {
        let top = listTopInset
        if tableView.contentInset.top != top {
            // A list resting at its top stays there when the header's height changes.
            let wasAtTop = tableView.contentOffset.y <= -tableView.adjustedContentInset.top + 0.5
            tableView.contentInset.top = top
            tableView.verticalScrollIndicatorInsets.top = top
            if wasAtTop, didApplyInitialOffset {
                tableView.contentOffset.y = -tableView.adjustedContentInset.top
            }
        }
        let bottom = listBottomInset
        guard tableView.contentInset.bottom != bottom else { return }
        tableView.contentInset.bottom = bottom
        tableView.verticalScrollIndicatorInsets.bottom = bottom
    }

    /// The system's soft edge effect: rows blur and fade under the header and, in select mode,
    /// under the toolbar. Both are containers of views that overlay the table's edges.
    @available(iOS 26.0, *)
    private func setupNativeEdgeEffects() {
        tableView.topEdgeEffect.style = .soft
        tableView.bottomEdgeEffect.style = .soft

        let headerInteraction = UIScrollEdgeElementContainerInteraction()
        headerInteraction.scrollView = tableView
        headerInteraction.edge = .top
        headerView.addInteraction(headerInteraction)
        // The header lies over the table: a drag that starts on it scrolls the list.
        headerView.isUserInteractionEnabled = false
        view.bringSubviewToFront(headerView)

        let toolbarInteraction = UIScrollEdgeElementContainerInteraction()
        toolbarInteraction.scrollView = tableView
        toolbarInteraction.edge = .bottom
        selectionToolbar.addInteraction(toolbarInteraction)
    }

    /// The counts' capsule fades in over the gap between the header and the first row: it is solid
    /// once rows reach the header, and gone while the list rests at its top.
    private func updateStatsCapsule() {
        guard usesNativeEdgeEffects else { return }
        let scrolled = tableView.contentOffset.y + tableView.adjustedContentInset.top
        let alpha = min(max(scrolled / Layout.headerToList, 0), 1)
        if statsCapsuleView.alpha != alpha {
            statsCapsuleView.alpha = alpha
        }
    }

    /// The top blur shows only as far as rows have scrolled under it.
    private func updateTopBlur() {
        guard !usesNativeEdgeEffects else { return }
        topBlurView.setContentOverlap(tableView.contentOffset.y + tableView.adjustedContentInset.top)
    }

    /// The bottom blur shows only while rows sit under it.
    private func updateBottomBlur() {
        guard !usesNativeEdgeEffects else { return }
        let visibleBottom = tableView.contentOffset.y + tableView.bounds.height - tableView.adjustedContentInset.bottom
        bottomBlurView.setContentOverlap(tableView.contentSize.height - visibleBottom)
    }

    /// The bar sits on the same grouped background as the header and list (no material band).
    private func applyTransparentNavigationBar() {
        let appearance = UINavigationBarAppearance(barAppearance: UINavigationBar.appearance().standardAppearance)
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = UINavigationBar.appearance().standardAppearance.titleTextAttributes
        appearance.largeTitleTextAttributes = UINavigationBar.appearance().standardAppearance.largeTitleTextAttributes
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
    }

    private func calculateThumbnailSize() {
        let scale = traitCollection.displayScale
        let size: CGFloat = 60
        thumbnailSize = CGSize(width: size * scale, height: size * scale)
    }

    // MARK: - Header Counts

    private func updateStatsLabel() {
        let stats = historyManager.getStatistics()
        let totalCount = historyManager.undoCount
        let numberAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        ]

        let attributedString = NSMutableAttributedString()

        // A thin drawn divider follows the count.
        let countString = Strings.itemCount(totalCount)
        attributedString.append(
            NSAttributedString(string: countString + "   ", attributes: [.foregroundColor: UIColor.secondaryLabel]))
        let divider = NSTextAttachment()
        divider.image = Self.dividerImage(color: UIColor.separator.resolvedColor(with: traitCollection))
        divider.bounds = CGRect(x: 0, y: -2, width: 1, height: 14)
        attributedString.append(NSAttributedString(attachment: divider))
        attributedString.append(NSAttributedString(string: "   "))

        func appendIcon(_ name: String, color: UIColor, size: CGSize, count: Int, trailing: String) {
            if let image = UIImage(systemName: name)?.withTintColor(color, renderingMode: .alwaysOriginal) {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(x: 0, y: -2, width: size.width, height: size.height)
                attributedString.append(NSAttributedString(attachment: attachment))
            }
            attributedString.append(NSAttributedString(string: " \(count)\(trailing)", attributes: numberAttributes))
        }

        typealias ActionType = UndoAction.ActionType
        appendIcon("trash.fill", color: ActionType.delete.displayColor, size: CGSize(width: 15, height: 15), count: stats.deleted, trailing: "  ")
        appendIcon("checkmark.circle.fill", color: ActionType.keep.displayColor, size: CGSize(width: 15, height: 15), count: stats.kept, trailing: "  ")
        appendIcon("archivebox.fill", color: ActionType.store.displayColor, size: CGSize(width: 16, height: 14), count: stats.stored, trailing: "")

        statsLabel.attributedText = attributedString
    }

    private static func dividerImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 1, height: 14)
        return UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func setupOptionsMenu() {
        let selectAction = UIAction(
            title: NSLocalizedString("undoHistory.selectMultiple", comment: "Select multiple button"),
            image: UIImage(systemName: "checkmark.circle")
        ) { [weak self] _ in
            self?.toggleEditMode()
        }

        let undoAllAction = UIAction(
            title: NSLocalizedString("undoHistory.undoAllTitle", comment: "Undo all button"),
            image: UIImage(systemName: "arrow.uturn.backward.circle"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.handleUndoAll()
        }

        let menu = UIMenu(title: "", children: [selectAction, undoAllAction])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: menu
        )
    }

    private func updateToolbarButtonsState() {
        let hasSelection = tableView.indexPathsForSelectedRows?.isEmpty == false
        keepButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection

        storeButton.isEnabled = hasSelection
        undoButton.isEnabled = hasSelection
    }

    private func toggleEditMode() {
        isEditMode.toggle()
        // Not the table's editing mode: its selection circles show a tick, which reads as Keep.
        // The rows draw their own dot (`UndoHistoryCell.setSelecting`).
        if !isEditMode {
            tableView.indexPathsForSelectedRows?.forEach { tableView.deselectRow(at: $0, animated: false) }
        }
        tableView.allowsMultipleSelection = isEditMode
        for cell in tableView.visibleCells {
            (cell as? UndoHistoryCell)?.setSelecting(isEditMode, animated: true)
        }
        updateSeparatorsAboveSelection()
        selectionToolbar.isHidden = !isEditMode

        // While selecting, the last row rests 12pt above the toolbar; rows still scroll under it,
        // and the bottom blur grows to cover the buttons.
        bottomBlurBandTopConstraint?.isActive = !isEditMode
        bottomBlurToolbarTopConstraint?.isActive = isEditMode
        UIView.animate(withDuration: 0.25) {
            self.updateListInsets()
            self.view.layoutIfNeeded()
        }
        updateBottomBlur()

        if isEditMode {
            updateToolbarButtonsState()
            // A titled Done, not the system's tick, which reads as Keep.
            let doneItem = UIBarButtonItem(
                title: Strings.done, style: .done, target: self, action: #selector(handleEditDone))
            if #available(iOS 26.0, *) {
                doneItem.style = .prominent
            }
            // Blue like the selection dots; the app's tint would read as Keep.
            doneItem.tintColor = .systemBlue
            navigationItem.rightBarButtonItem = doneItem
        } else {
            setupOptionsMenu()
        }
    }

    @objc private func handleEditDone() {
        toggleEditMode()
    }

    private func handleUndoAll() {
        let alert = UIAlertController(
            title: NSLocalizedString("undoHistory.undoAllTitle", comment: "Undo all alert title"),
            message: NSLocalizedString("undoHistory.undoAllMessage", comment: "Undo all confirmation message"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: CommonStrings.cancel, style: .cancel))
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("undoHistory.undoAllTitle", comment: "Undo all button"), style: .destructive) { [weak self] _ in
                self?.performUndoAll()
            })

        present(alert, animated: true)
    }

    private func performUndoAll() {
        let actions = historyManager.popAll()

        delegate?.didUndoAll(actions)

        tableView.reloadData()
        updateStatsLabel()

        dismiss(animated: true)
    }

    @objc private func handleKeepSelected() {
        applyActionToSelectedRows(.keep)
    }

    @objc private func handleDeleteSelected() {
        applyActionToSelectedRows(.delete)
    }

    @objc private func handleStoreSelected() {
        applyActionToSelectedRows(.store)
    }

    @objc private func handleUndoSelected() {
        guard let selectedRows = tableView.indexPathsForSelectedRows, !selectedRows.isEmpty else { return }

        let selectedActions = selectedRows.map { actions[$0.row] }
        let selectedIDs = Set(selectedActions.map { $0.id })

        let undoneActions = historyManager.removeActions(withIDs: selectedIDs)

        delegate?.didUndoActions(undoneActions)

        toggleEditMode()
        tableView.reloadData()
        updateStatsLabel()

        if historyManager.undoCount == 0 {
            dismiss(animated: true)
        }
    }

    private func applyActionToSelectedRows(_ actionType: UndoAction.ActionType) {
        guard let selectedRows = tableView.indexPathsForSelectedRows, !selectedRows.isEmpty else { return }

        // Sort in reverse order to handle index changes
        let sortedRows = selectedRows.sorted { $0.row > $1.row }

        for indexPath in sortedRows {
            handleAction(actionType, forIndexPath: indexPath)
        }

        toggleEditMode()
    }

    // MARK: - Actions
    @objc private func handleDone() {
        dismiss(animated: true)
    }

    private func handleAction(_ actionType: UndoAction.ActionType, forIndexPath indexPath: IndexPath) {
        let action = actions[indexPath.row]

        _ = historyManager.updateAction(at: indexPath.row, newActionType: actionType)
        delegate?.didPerformAction(actionType, on: action)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateStatsLabel()
    }
}

// MARK: - UITableViewDataSource
extension UndoHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        actions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UndoHistoryCell", for: indexPath) as! UndoHistoryCell
        let action = actions[indexPath.row]

        if let cachedImage = thumbnailCache[action.assetLocalIdentifier] {
            cell.configure(with: action, thumbnail: cachedImage)
            return cell
        }

        let fetchOptions = PHFetchOptions()
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [action.assetLocalIdentifier], options: fetchOptions)

        if let asset = result.firstObject {
            ImageCacheService.shared.loadImage(
                for: asset,
                quality: .thumbnail,
                screenSize: CGSize(width: 60, height: 60),
                allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
                traitCollection: traitCollection
            ) { [weak self] image, _, _ in
                if let image = image {
                    self?.thumbnailCache[action.assetLocalIdentifier] = image
                }
                cell.configure(with: action, thumbnail: image)
            }
        } else {
            cell.configureAsDeleted(with: action)   // Asset was permanently deleted - show placeholder
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension UndoHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditMode {
            updateToolbarButtonsState()
            updateSeparatorsAboveSelection()
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        let action = actions[indexPath.row]

        //  better quality for sheet
        let fetchOptions = PHFetchOptions()
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [action.assetLocalIdentifier], options: fetchOptions)

        guard let asset = result.firstObject else { return }

        ImageCacheService.shared.loadImage(
            for: asset,
            quality: .full,
            screenSize: CGSize(width: 1000, height: 1000),
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
            traitCollection: traitCollection
        ) { [weak self] image, _, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let bottomSheet = HistoryDetailBottomSheet(action: action, image: image, asset: asset)

                bottomSheet.onKeepTapped = { [weak self] in
                    self?.handleAction(.keep, forIndexPath: indexPath)
                }

                bottomSheet.onDeleteTapped = { [weak self] in
                    self?.handleAction(.delete, forIndexPath: indexPath)
                }

                bottomSheet.onStoreTapped = { [weak self] in
                    self?.handleAction(.store, forIndexPath: indexPath)
                }

                self.present(bottomSheet, animated: true)
            }
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if isEditMode {
            updateToolbarButtonsState()
            updateSeparatorsAboveSelection()
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let cell = cell as? UndoHistoryCell else { return }
        cell.setSelecting(isEditMode, animated: false)
        cell.hidesSeparator = isEditMode && isRowSelected(indexPath.row + 1)
    }

    private func isRowSelected(_ row: Int) -> Bool {
        tableView.indexPathsForSelectedRows?.contains { $0.row == row } ?? false
    }

    /// A row's separator is the line above the next row, so hide it while the next row is selected.
    private func updateSeparatorsAboveSelection() {
        for indexPath in tableView.indexPathsForVisibleRows ?? [] {
            (tableView.cellForRow(at: indexPath) as? UndoHistoryCell)?.hidesSeparator =
                isEditMode && isRowSelected(indexPath.row + 1)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        .leastNonzeroMagnitude
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateTopBlur()
        updateBottomBlur()
        updateStatsCapsule()
    }
}

// MARK: - Strings

private enum Strings {
    static let keep = NSLocalizedString("undoHistory.keep", comment: "Keep button")
    static let delete = NSLocalizedString("undoHistory.delete", comment: "Delete button")
    static let store = NSLocalizedString("undoHistory.store", comment: "Store button")
    static let undo = NSLocalizedString("undoHistory.undo", comment: "Undo button")
    static let done = NSLocalizedString("undoHistory.done", comment: "Ends selecting rows")
    /// The selection toolbar's titles, for measuring the widest one.
    static let toolbarTitles = [keep, delete, store, undo]

    static func itemCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("undoHistory.itemCount", comment: "Item count, e.g. '5 items'"), count)
    }
}

@available(iOS 17.0, *)
#Preview {
    UINavigationController(rootViewController: UndoHistoryViewController())
}

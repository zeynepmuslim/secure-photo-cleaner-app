//
//  MonthReviewViewController+TablePose.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

// MARK: - Strings

private enum Strings {
    static let delete = CommonStrings.delete
    static let keep = NSLocalizedString("monthReview.keep", comment: "Keep swipe action label")
    static let store = NSLocalizedString("monthReview.store", comment: "Store swipe action label")
    static let swipeArea = NSLocalizedString(
        "monthReview.tableLayoutSwipeArea", comment: "iPhone Duo table pose: the swipe area layout (menu item, VoiceOver label)")
    static let trackpadHint = NSLocalizedString(
        "monthReview.trackpadHint", comment: "iPhone Duo table pose: hint under the swipe area")
    static let buttons = NSLocalizedString(
        "monthReview.tableLayoutButtons", comment: "iPhone Duo table pose: the Store / Delete / Keep keys layout (menu item)")
    static let layout = NSLocalizedString(
        "monthReview.tableLayout", comment: "iPhone Duo table pose: bar button that picks the controls layout")
}

// iPhone Duo table pose (upright inner display, partly folded, horizontal fold), boards T1 / T4:
// - Raised half: the stats label at the top, then the card deck down to the fold. The card keeps
//   its own pan gesture.
// - Base: the selected control (tableBaseGuide, from the fold + 12 down to the bottom row − 12),
//   with the card's side edges (safe area, EdgePadding.content, rail).
// - The bottom row (Undo, History, bin) stays as it is.
// Flat, book, sideways (+Landscape) and the cover display never activate this.
extension MonthReviewViewController {

    /// Builds the base guide and its container once, the first time the table pose shows.
    /// Its constraints join `tablePoseLayoutConstraints`, so +Fold swaps them with the rest.
    func setupTablePoseViewsIfNeeded() {
        guard !hasSetupTablePoseViews, cardContainerView.superview != nil else { return }
        hasSetupTablePoseViews = true

        view.addLayoutGuide(tableBaseGuide)
        // Under the card so a card flying off passes over the base controls
        view.insertSubview(tableBaseContainerView, belowSubview: cardContainerView)
        // Hidden with the deck: while the skeleton loads, on the empty state and the completion
        // summary (hideSkeletonLoading, showEmptyState and showCompletionSummary set it too)
        tableBaseContainerView.alpha = cardContainerView.alpha

        // T1: a swipe pad. Its pan runs handlePan, which reads the drag in `view`, so the raised
        // card moves exactly like a direct swipe. VoiceOver gets one action per direction.
        tablePoseTrackpadView.configure(
            storeTitle: Strings.store, deleteTitle: Strings.delete, keepTitle: Strings.keep,
            areaTitle: Strings.swipeArea, hint: Strings.trackpadHint)
        tablePoseTrackpadView.panGesture.addTarget(self, action: #selector(handlePan(_:)))
        tablePoseTrackpadView.onStore = { [weak self] in self?.performGripAction(.up) }
        tablePoseTrackpadView.onDelete = { [weak self] in self?.performGripAction(.left) }
        tablePoseTrackpadView.onKeep = { [weak self] in self?.performGripAction(.right) }

        // T4: Store over Delete and Keep, the same path as a swipe (like the sideways grips)
        tablePoseKeysView.configure(storeTitle: Strings.store, deleteTitle: Strings.delete, keepTitle: Strings.keep)
        tablePoseKeysView.onStore = { [weak self] in self?.performGripAction(.up) }
        tablePoseKeysView.onDelete = { [weak self] in self?.performGripAction(.left) }
        tablePoseKeysView.onKeep = { [weak self] in self?.performGripAction(.right) }

        tableBaseContainerView.addSubview(tablePoseTrackpadView)
        tableBaseContainerView.addSubview(tablePoseKeysView)
        showTablePoseControls(settingsStore.tablePoseControlsLayout)

        // Moved below the fold on every layout pass (+Fold)
        let baseTop = tableBaseGuide.topAnchor.constraint(equalTo: view.topAnchor)
        tableBaseTopConstraint = baseTop

        tablePoseLayoutConstraints += [
            baseTop,
            tableBaseGuide.bottomAnchor.constraint(
                equalTo: bottomControlsStack.topAnchor, constant: -Layout.foldGap),
            // The card's edges follow the safe area and the rail (DuoEdgeConstraints)
            tableBaseGuide.leadingAnchor.constraint(equalTo: cardContainerView.leadingAnchor),
            tableBaseGuide.trailingAnchor.constraint(equalTo: cardContainerView.trailingAnchor),

            tableBaseContainerView.topAnchor.constraint(equalTo: tableBaseGuide.topAnchor),
            tableBaseContainerView.leadingAnchor.constraint(equalTo: tableBaseGuide.leadingAnchor),
            tableBaseContainerView.trailingAnchor.constraint(equalTo: tableBaseGuide.trailingAnchor),
            tableBaseContainerView.bottomAnchor.constraint(equalTo: tableBaseGuide.bottomAnchor)
        ]
        // Both controls fill the base; only the chosen one shows
        for control in [tablePoseTrackpadView, tablePoseKeysView] as [UIView] {
            tablePoseLayoutConstraints += [
                control.topAnchor.constraint(equalTo: tableBaseContainerView.topAnchor),
                control.leadingAnchor.constraint(equalTo: tableBaseContainerView.leadingAnchor),
                control.trailingAnchor.constraint(equalTo: tableBaseContainerView.trailingAnchor),
                control.bottomAnchor.constraint(equalTo: tableBaseContainerView.bottomAnchor)
            ]
        }
    }

    /// Shows the trackpad or the keys on the base.
    func showTablePoseControls(_ layout: TablePoseControlsLayout) {
        tablePoseTrackpadView.isHidden = layout != .trackpad
        tablePoseKeysView.isHidden = layout != .keys
    }

    // MARK: - Layout Menu

    /// Adds or removes the Layout bar item. Called only when the table pose starts or ends,
    /// never on every layout pass. Other items (the filter progress ring) stay where they are.
    func setTableLayoutBarItemVisible(_ isVisible: Bool) {
        var items = navigationItem.rightBarButtonItems ?? []
        if isVisible {
            let item = tableLayoutBarItem ?? .tableLayoutItem(
                title: Strings.layout, layout: settingsStore.tablePoseControlsLayout, menu: makeTableLayoutMenu())
            tableLayoutBarItem = item
            guard !items.contains(item) else { return }
            if #available(iOS 27.1, *) {
                // The progress ring overflows last
                items.forEach { $0.visibilityPriority = .high }
                item.visibilityPriority = .low
            }
            // The first item is the outermost, so the ring keeps its place
            items.append(item)
        } else {
            guard let item = tableLayoutBarItem, items.contains(item) else { return }
            items.removeAll { $0 === item }
        }
        navigationItem.setRightBarButtonItems(items.isEmpty ? nil : items, animated: view.window != nil)
    }

    private func makeTableLayoutMenu() -> UIMenu {
        let current = settingsStore.tablePoseControlsLayout
        let choices: [(TablePoseControlsLayout, String)] = [(.trackpad, Strings.swipeArea), (.keys, Strings.buttons)]
        let actions = choices.map { layout, title in
            UIAction(
                title: title, image: UIBarButtonItem.tableLayoutImage(for: layout), state: layout == current ? .on : .off
            ) { [weak self] _ in
                self?.selectTablePoseControlsLayout(layout)
            }
        }
        return UIMenu(options: .singleSelection, children: actions)
    }

    private func selectTablePoseControlsLayout(_ layout: TablePoseControlsLayout) {
        guard layout != settingsStore.tablePoseControlsLayout else { return }
        settingsStore.tablePoseControlsLayout = layout
        haptics.selection()
        UIView.transition(
            with: tableBaseContainerView, duration: 0.25,
            options: [.transitionCrossDissolve, .allowUserInteraction]
        ) {
            self.showTablePoseControls(layout)
        }
        tableLayoutBarItem?.image = UIBarButtonItem.tableLayoutImage(for: layout)
        tableLayoutBarItem?.menu = makeTableLayoutMenu()
    }

    /// Mirrors the top card on the trackpad as a mini box: its aspect ratio, and its drag, turn and
    /// fly-off. Called from handlePan, springBackTopCard, completeSwipe (inside their animation
    /// blocks), layoutCards and when the pose starts. While the top card flies off it's
    /// still the last in `cardStack`, so the mini card flies off with it.
    func updateTablePosePreview() {
        guard hasSetupTablePoseViews else { return }
        let top = cardStack.last(where: { !$0.isHidden })
        let ratio = top.flatMap { card in
            card.contentAspectRatio ?? (card.bounds.height > 0 ? card.bounds.width / card.bounds.height : nil)
        }
        tablePoseTrackpadView.setPreview(aspectRatio: ratio, identifier: top?.assetIdentifier)
        if let top = top {
            tablePoseTrackpadView.setPreviewTransform(top.transform, cardWidth: top.bounds.width)
        }
    }

    /// Places the base just below the fold. Called on every layout pass in table pose.
    func updateTableBase(fold: CGRect) {
        let top = fold.maxY + Layout.foldGap
        guard let constraint = tableBaseTopConstraint, constraint.constant != top else { return }
        constraint.constant = top
    }

    func setTablePoseControlsVisible(_ isVisible: Bool) {
        // Leaving the table pose mid-drag: cancel, so handlePan springs the card back
        if !isVisible { tablePoseTrackpadView.cancelActiveDrag() }
        tableBaseContainerView.isHidden = !isVisible
        if isVisible { updateTablePosePreview() }
    }

    /// A trackpad drag that's cancelled (the pose changed under it) springs back instead of
    /// completing a swipe from wherever the finger was.
    func isCancelledTrackpadDrag(_ gesture: UIPanGestureRecognizer) -> Bool {
        gesture.state == .cancelled && gesture === tablePoseTrackpadView.panGesture
    }
}

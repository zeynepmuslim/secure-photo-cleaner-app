//
//  MonthReviewViewController+Fold.swift
//  Purgio
//
//  Created by ZeynepMüslim on 06.10.2026.
//

import UIKit

// iPhone Duo fold handling. The fold is read on every layout pass.
// - Vertical fold (book pose, and fully open so the row doesn't jump): undo ends before
//   the fold and history starts after it. The card stays (it is content); the centered
//   video play button moves to the larger side of the fold while folded.
// - Table layout (table pose, and the upright inner display fully open, board O2): stats + card
//   above the horizontal fold, the base controls below it (+TablePose, tableLayoutFold()).
//   The deck fans out there like sideways (+Landscape), so the next cards show behind the top one.
//   Partly folded the split is at the fold; fully open the deck gets about 70% and the keys 30%.
//   Folding and unfolding animate between the two and switch the base between the keys (fully
//   open) and the saved control (partly folded). It switches on or off as a whole.
// Same controls, actions and gestures in every pose.
extension MonthReviewViewController {

    private enum FoldLayout {
        static let playPauseHalfWidth: CGFloat = 40
    }

    func updateFoldLayout() {
        // The main UI is built after the first appearance (the push lays out before it). Until then
        // there's nothing to place, and recording the layout early would skip the first real switch.
        guard cardContainerView.superview != nil else { return }
        let fold = FoldRegion.activeFold(in: view)
        let pose = FoldRegion.pose(for: fold)
        // The sideways layout splits its own row and video controls at the fold (+Landscape)
        if isLandscapeDeckActive {
            applyTableLayout(fold: nil, isFolded: false)
            updateLandscapeFoldSplit()
            return
        }
        applyTableLayout(fold: tableLayoutFold(), isFolded: pose == .table)
        // The real pose: a horizontal fold (table layout) never moves the play button or splits the row
        updatePlayPauseFoldOffset(fold: pose == .book ? fold : nil)
        updateControlsFoldSplit()
    }

    /// Splits the undo/history row at a vertical fold: the gap is centered on the fold line,
    /// the regular spacing while fully open and the whole fold region while folded.
    private func updateControlsFoldSplit() {
        guard let equalWidths = undoHistoryEqualWidthConstraint,
              let undoTrailing = undoTrailingToFoldConstraint else { return }
        let spacing = bottomControlsStack.spacing
        var split: (constant: CGFloat, gap: CGFloat)?

        if let fold = FoldRegion.splittingFold(in: view), fold.height > fold.width {
            let gap = FoldRegion.activeFold(in: view).map { max(spacing, $0.width) } ?? spacing
            // Distances from the leading edge, so the constraint works in both layout directions
            let isLeftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
            let foldCenter = isLeftToRight ? fold.midX : view.bounds.width - fold.midX
            let rowStart = isLeftToRight
                ? bottomControlsStack.frame.minX
                : view.bounds.width - bottomControlsStack.frame.maxX
            let constant = foldCenter - gap / 2
            // Only when undo keeps a full button width before the fold
            if constant - rowStart >= GeneralConstants.ButtonSize.large {
                split = (constant, gap)
            }
        }

        if let split = split {
            if equalWidths.isActive { equalWidths.isActive = false }
            if undoTrailing.constant != split.constant { undoTrailing.constant = split.constant }
            if !undoTrailing.isActive { undoTrailing.isActive = true }
            if bottomControlsStack.customSpacing(after: undoButton) != split.gap {
                bottomControlsStack.setCustomSpacing(split.gap, after: undoButton)
            }
        } else {
            if undoTrailing.isActive { undoTrailing.isActive = false }
            if !equalWidths.isActive { equalWidths.isActive = true }
            if bottomControlsStack.customSpacing(after: undoButton) != spacing {
                bottomControlsStack.setCustomSpacing(spacing, after: undoButton)
            }
        }
    }

    /// Sideways ↔ upright (+Landscape): switches the table layout in the same pass and without
    /// animation, so the deck doesn't animate out of the old layout after the new one is laid out.
    func syncTableLayoutWithoutAnimation() {
        guard cardContainerView.superview != nil else { return }
        let isFolded = FoldRegion.pose(for: FoldRegion.activeFold(in: view)) == .table
        applyTableLayout(
            fold: isLandscapeDeckActive ? nil : tableLayoutFold(), isFolded: isFolded && !isLandscapeDeckActive,
            animated: false)
    }

    /// Places the table layout at `fold` on every pass (constants only). Turning it on or off swaps
    /// the constraint sets, shows or hides the base and re-fans the deck. Folding or unfolding while
    /// it's on swaps the split (at the fold, or 70/30 fully open), resizes the deck and switches the
    /// base's control and the Layout bar item (+TablePose).
    private func applyTableLayout(fold: CGRect?, isFolded: Bool, animated: Bool = true) {
        let wasFolded = isTableLayoutFolded
        // Before the views are set up, so the base starts with the right control
        isTableLayoutFolded = fold != nil && isFolded
        if let fold = fold {
            // Before the constants below, so the base's constraints exist the first time
            setupTablePoseViewsIfNeeded()
            let cardBottom = fold.minY - Layout.foldGap
            if cardBottomToFoldConstraint?.constant != cardBottom {
                cardBottomToFoldConstraint?.constant = cardBottom
            }
            updateTableBase(fold: fold)
        }

        let isTable = fold != nil
        guard isTableLayoutActive != isTable else {
            if isTable, wasFolded != isTableLayoutFolded {
                updateTableSplitConstraints()
                updateTableControlsForFold(animated: animated && view.window != nil)
                relayoutDeckForTableLayoutChange(animated: animated)
            }
            return
        }
        isTableLayoutActive = isTable

        if isTable {
            NSLayoutConstraint.deactivate(flatLayoutConstraints)
            NSLayoutConstraint.activate(tablePoseLayoutConstraints)
            updateTableSplitConstraints()
        } else {
            updateTableSplitConstraints()
            NSLayoutConstraint.deactivate(tablePoseLayoutConstraints)
            NSLayoutConstraint.activate(flatLayoutConstraints)
        }
        setTablePoseControlsVisible(isTable)
        updateTableControlsForFold(animated: false)
        applyScreenBackground()
        relayoutDeckForTableLayoutChange(animated: animated)
    }

    /// Activates the table layout's split for the fold state: at the fold while partly folded, the
    /// 70/30 split while fully open, neither outside the table layout.
    private func updateTableSplitConstraints() {
        let active = isTableLayoutActive
            ? (isTableLayoutFolded ? tableFoldedConstraints : tableOpenConstraints)
            : []
        let inactive = (tableFoldedConstraints + tableOpenConstraints).filter { constraint in
            constraint.isActive && !active.contains { $0 === constraint }
        }
        NSLayoutConstraint.deactivate(inactive)
        NSLayoutConstraint.activate(active.filter { !$0.isActive })
    }

    /// Lays the card area out again and re-sizes and re-fans the cards inside it (+Landscape).
    private func relayoutDeckForTableLayoutChange(animated: Bool) {
        guard view.window != nil else {
            refreshCardsForLayoutChange()
            return
        }
        guard animated else {
            view.layoutIfNeeded()
            refreshCardsForLayoutChange()
            return
        }
        // Animate outside the current layout pass
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.3) {
                // Card area first, then the cards sized and fanned inside its new bounds
                self.view.layoutIfNeeded()
                self.refreshCardsForLayoutChange()
                self.view.layoutIfNeeded()
            }
        }
    }

    private func updatePlayPauseFoldOffset(fold: CGRect?) {
        guard let constraint = playPauseCenterXConstraint else { return }
        var offset: CGFloat = 0

        if let fold = fold {
            let card = cardContainerView.bounds
            let foldInCard = cardContainerView.convert(fold, from: view)
            let buttonMinX = card.midX - FoldLayout.playPauseHalfWidth
            let buttonMaxX = card.midX + FoldLayout.playPauseHalfWidth

            if foldInCard.minX < buttonMaxX && foldInCard.maxX > buttonMinX {
                let leftWidth = max(0, foldInCard.minX - card.minX)
                let rightWidth = max(0, card.maxX - foldInCard.maxX)
                let targetX = leftWidth >= rightWidth
                    ? card.minX + leftWidth / 2
                    : foldInCard.maxX + rightWidth / 2
                offset = targetX - card.midX
            }
        }

        guard constraint.constant != offset else { return }
        constraint.constant = offset
    }
}

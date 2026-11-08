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
// - Table pose: card on the raised half, stats + controls on the flat base.
// Same controls, actions and gestures in every pose.
extension MonthReviewViewController {

    private enum FoldLayout {
        static let gap: CGFloat = 12
        static let playPauseHalfWidth: CGFloat = 40
    }

    func updateFoldLayout() {
        let fold = FoldRegion.activeFold(in: view)
        let pose = FoldRegion.pose(for: fold)
        // The sideways layout splits its own row and video controls at the fold (+Landscape)
        if isLandscapeDeckActive {
            applyFoldPose(pose == .table ? .flat : pose, fold: fold)
            updateLandscapeFoldSplit()
            return
        }
        applyFoldPose(pose, fold: fold)
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

    private func applyFoldPose(_ pose: FoldRegion.Pose, fold: CGRect?) {
        if pose == .table, let fold = fold {
            let cardBottom = fold.minY - FoldLayout.gap
            let statsTop = fold.maxY + FoldLayout.gap
            if cardBottomToFoldConstraint?.constant != cardBottom {
                cardBottomToFoldConstraint?.constant = cardBottom
            }
            if statsTopToFoldConstraint?.constant != statsTop {
                statsTopToFoldConstraint?.constant = statsTop
            }
        }

        let wasTable = currentFoldPose == .table
        let isTable = pose == .table
        currentFoldPose = pose
        guard wasTable != isTable else { return }

        if isTable {
            NSLayoutConstraint.deactivate(flatLayoutConstraints)
            NSLayoutConstraint.activate(tablePoseLayoutConstraints)
        } else {
            NSLayoutConstraint.deactivate(tablePoseLayoutConstraints)
            NSLayoutConstraint.activate(flatLayoutConstraints)
        }

        guard view.window != nil else { return }
        // Animate outside the current layout pass
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.3) {
                self?.view.layoutIfNeeded()
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

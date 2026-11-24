//
//  SimilarPhotosViewController+Fold.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import UIKit

// MARK: - iPhone Duo inner display

extension SimilarPhotosViewController {

    /// Picks the layout for where the fold crosses the view, on every layout pass:
    /// - a vertical fold (held sideways): two columns in one scroll view, a set on each side;
    /// - a horizontal fold in regular width (upright, fully open and in the table pose): the
    ///   summary card and a spotlight set on the raised half, the list on the base;
    /// - no fold (phones, the cover display, Split View): one column.
    ///
    /// The gap sits on the fold: `Spacer.foldGap` centered on the fold line while fully open,
    /// the whole fold region while partly folded. Switching layouts is never animated; folding
    /// and unfolding within one springs.
    func updateFoldSplit() {
        var fold = FoldRegion.splittingFold(in: view)
        // The cover display's fold reading is never a split
        if let candidate = fold, candidate.width >= candidate.height,
           traitCollection.horizontalSizeClass != .regular {
            fold = nil
        }
        let layout: SplitLayout = fold.map { $0.height > $0.width ? .sideways : .upright } ?? .single
        let isFolded = FoldRegion.activeFold(in: view) != nil

        let layoutChanged = layout != splitLayout || !hasAppliedSplitLayout
        if layoutChanged {
            applySplitLayout(layout)
        }

        var gap: CGFloat = 0
        var firstEdge: CGFloat = 0
        var secondEdge: CGFloat = 0
        if let fold {
            let isVertical = layout == .sideways
            let foldStart = isVertical ? fold.minX : fold.minY
            let foldLength = isVertical ? fold.width : fold.height
            let foldCenter = foldStart + foldLength / 2
            gap = isFolded ? max(GeneralConstants.Spacer.foldGap, foldLength) : GeneralConstants.Spacer.foldGap
            firstEdge = foldCenter - gap / 2
            secondEdge = foldCenter + gap / 2

            if isVertical {
                setConstant(secondEdge, of: bottomRowStartConstraint)
            } else {
                setConstant(firstEdge, of: raisedBottomConstraint)
                setConstant(secondEdge, of: baseTopConstraint)
            }
        }

        // The list's views aren't the view's own subviews, so a constraint changed here doesn't
        // bring another viewDidLayoutSubviews: lay them out now, before their frames are read
        let foldChanged = isFolded != isFoldActive
        isFoldActive = isFolded
        if foldChanged, !layoutChanged, layout != .single, view.window != nil {
            UIView.animate(
                withDuration: Layout.springDuration, delay: 0,
                usingSpringWithDamping: Layout.springDamping, initialSpringVelocity: Layout.springVelocity,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.listContentView.layoutIfNeeded()
            }
        } else if layoutChanged {
            UIView.performWithoutAnimation { listContentView.layoutIfNeeded() }
        } else {
            listContentView.layoutIfNeeded()
        }

        var metrics = ListMetrics()
        metrics.layout = layout
        metrics.spacing = isShortColumn ? Layout.compactCardSpacing : Layout.cardSpacing
        if layout == .sideways {
            // The columns' widths in the list's own coordinates, whole points so the pair
            // never outgrows the row
            let frame = collectionView.frame
            metrics.firstColumnWidth = max(0, floor(firstEdge - frame.minX))
            metrics.secondColumnWidth = max(0, floor(frame.maxX - secondEdge))
            metrics.columnGap = max(0, frame.width - metrics.firstColumnWidth - metrics.secondColumnWidth)
            if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
                swap(&metrics.firstColumnWidth, &metrics.secondColumnWidth)
            }
        }
        setListMetrics(metrics)
    }

    private func setConstant(_ constant: CGFloat, of constraint: NSLayoutConstraint?) {
        guard let constraint, constraint.constant != constant else { return }
        constraint.constant = constant
    }

    /// Swaps the layout's constraint set and what goes with it, without animation: the switch
    /// can land inside a push or a rotation.
    private func applySplitLayout(_ layout: SplitLayout) {
        hasAppliedSplitLayout = true
        splitLayout = layout
        UIView.performWithoutAnimation {
            NSLayoutConstraint.deactivate(singleConstraints + sidewaysConstraints + uprightConstraints)
            switch layout {
            case .single: NSLayoutConstraint.activate(singleConstraints)
            case .sideways: NSLayoutConstraint.activate(sidewaysConstraints)
            case .upright: NSLayoutConstraint.activate(uprightConstraints)
            }

            raisedContainer.isHidden = layout != .upright

            guard !similarGroups.isEmpty else { return }
            exitStoreModeOnAllCards(except: nil)
            spotlightIndex = nil
            updateSpotlight(animated: false)
            refreshSummary()
        }
    }

    // MARK: Spotlight

    /// Upright, the raised half shows the first set that isn't confirmed; the base lists the
    /// rest. Confirming it brings the next one up in a cross-dissolve.
    func updateSpotlight(animated: Bool) {
        let target = splitLayout == .upright ? unconfirmedIndices.first : nil
        guard target != spotlightIndex || (target == nil && !spotlightCardView.isHidden) else {
            if let target { configureCard(spotlightCardView, forSetAt: target) }
            return
        }
        spotlightIndex = target

        let apply = {
            if let target {
                self.spotlightCardView.isHidden = false
                self.configureCard(self.spotlightCardView, forSetAt: target)
            } else {
                self.spotlightCardView.isHidden = true
            }
        }
        if animated, view.window != nil, splitLayout == .upright {
            UIView.transition(
                with: raisedContainer, duration: Layout.spotlightDissolve,
                options: [.transitionCrossDissolve, .allowUserInteraction], animations: apply)
        } else {
            apply()
        }
        applySnapshot(animated: animated && view.window != nil)
    }
}

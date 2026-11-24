//
//  ProcessingLoadingViewController+Fold.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.11.2026.
//

import UIKit

// MARK: - iPhone Duo inner display

extension ProcessingLoadingViewController {

    /// The three constraint sets `updateFoldSplit()` swaps between. Distances from the fold are
    /// constants from the content's leading edge (sideways) or top (upright), set on every pass.
    func makeSplitConstraints() {
        let rowStandardLeading = bottomRowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)

        // One column: the lead and the meter stacked, the pair centered in the room above the row
        let leadToMeter = meterAreaGuide.topAnchor.constraint(
            equalTo: leadAreaGuide.bottomAnchor, constant: Layout.leadToMeter)
        leadToMeterConstraint = leadToMeter
        let pairCenterY = pairGuide.centerYAnchor.constraint(equalTo: roomGuide.centerYAnchor)
        pairCenterY.priority = .defaultHigh
        singleConstraints = [
            rowStandardLeading,
            leadAreaGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leadAreaGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            leadAreaGuide.heightAnchor.constraint(equalTo: leadStack.heightAnchor),
            meterAreaGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            meterAreaGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            meterAreaGuide.heightAnchor.constraint(equalTo: meterView.heightAnchor),
            leadToMeter,
            pairGuide.topAnchor.constraint(equalTo: leadAreaGuide.topAnchor),
            pairGuide.bottomAnchor.constraint(equalTo: meterAreaGuide.bottomAnchor),
            pairGuide.topAnchor.constraint(greaterThanOrEqualTo: roomGuide.topAnchor),
            pairCenterY
        ]

        // Sideways: the lead in the leading half; the meter in the trailing half, the row under it
        let leadEnd = leadAreaGuide.trailingAnchor.constraint(equalTo: contentView.leadingAnchor)
        let meterStart = meterAreaGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        let rowStart = bottomRowStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor)
        sidewaysLeadEndConstraint = leadEnd
        sidewaysMeterStartConstraint = meterStart
        sidewaysBottomRowStartConstraint = rowStart
        sidewaysConstraints = [
            rowStart,
            leadAreaGuide.topAnchor.constraint(equalTo: contentView.topAnchor),
            leadAreaGuide.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            leadAreaGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leadEnd,
            meterStart,
            meterAreaGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            meterAreaGuide.topAnchor.constraint(equalTo: roomGuide.topAnchor),
            meterAreaGuide.bottomAnchor.constraint(equalTo: roomGuide.bottomAnchor)
        ]

        // Upright: the lead on the raised half; the meter on the base, the row along the bottom
        let raisedEnd = leadAreaGuide.bottomAnchor.constraint(equalTo: contentView.topAnchor)
        let baseStart = meterAreaGuide.topAnchor.constraint(equalTo: contentView.topAnchor)
        uprightLeadEndConstraint = raisedEnd
        uprightMeterStartConstraint = baseStart
        uprightConstraints = [
            rowStandardLeading,
            leadAreaGuide.topAnchor.constraint(equalTo: contentView.topAnchor),
            raisedEnd,
            leadAreaGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leadAreaGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            baseStart,
            meterAreaGuide.bottomAnchor.constraint(equalTo: roomGuide.bottomAnchor),
            meterAreaGuide.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            meterAreaGuide.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
        ]
    }

    /// Picks the layout for where the fold crosses the view, on every layout pass:
    /// - a vertical fold (held sideways): the filter in the leading half, the meter and the
    ///   bottom row in the trailing half;
    /// - a horizontal fold in regular width (upright, fully open and in the table pose): the
    ///   filter on the raised half, the meter and the bottom row on the base;
    /// - no fold (phones, the cover display, Split View): one column.
    ///
    /// The gap sits on the fold: `Spacer.foldGap` centered on the fold line while fully open,
    /// the whole fold region while partly folded, so folding moves only the gap. Switching
    /// layouts is never animated; folding and unfolding within one springs.
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

        var meterRoom: CGFloat?
        if let fold {
            // In the content's own coordinates, which the constants are measured in
            let frame = view.convert(fold, to: contentView)
            let isVertical = layout == .sideways
            let foldLength = isVertical ? frame.width : frame.height
            let foldCenter = isVertical ? frame.midX : frame.midY
            let gap = isFolded ? max(GeneralConstants.Spacer.foldGap, foldLength) : GeneralConstants.Spacer.foldGap
            var firstEdge = foldCenter - gap / 2
            var secondEdge = foldCenter + gap / 2

            if isVertical {
                if view.effectiveUserInterfaceLayoutDirection == .rightToLeft {
                    // Distances from the leading edge, which is on the right
                    let width = contentView.bounds.width
                    (firstEdge, secondEdge) = (width - secondEdge, width - firstEdge)
                }
                setConstant(firstEdge, of: sidewaysLeadEndConstraint)
                setConstant(secondEdge, of: sidewaysMeterStartConstraint)
                setConstant(secondEdge, of: sidewaysBottomRowStartConstraint)
            } else {
                setConstant(firstEdge, of: uprightLeadEndConstraint)
                setConstant(secondEdge, of: uprightMeterStartConstraint)
                meterRoom = contentView.bounds.height - bottomRowStack.bounds.height
                    - Layout.contentToBottomRow - secondEdge
            }
        }
        applyMetrics(for: layout, meterRoom: meterRoom)

        // The content's views aren't the view's own subviews, so a constraint changed here doesn't
        // bring another viewDidLayoutSubviews: lay them out now, before the bin's slot is read
        let foldChanged = isFolded != isFoldActive
        isFoldActive = isFolded
        if foldChanged, !layoutChanged, layout != .single, view.window != nil {
            UIView.animate(
                withDuration: Layout.springDuration, delay: 0,
                usingSpringWithDamping: Layout.springDamping, initialSpringVelocity: Layout.springVelocity,
                options: [.beginFromCurrentState, .allowUserInteraction]
            ) {
                self.contentView.layoutIfNeeded()
            }
        } else if layoutChanged {
            UIView.performWithoutAnimation { contentView.layoutIfNeeded() }
        } else {
            contentView.layoutIfNeeded()
        }
    }

    private func setConstant(_ constant: CGFloat, of constraint: NSLayoutConstraint?) {
        guard let constraint, constraint.constant != constant else { return }
        constraint.constant = constant
    }

    /// Swaps the layout's constraint set without animation: the switch can land inside a push
    /// or a rotation.
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
        }
    }
}

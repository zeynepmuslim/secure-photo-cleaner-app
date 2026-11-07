//
//  FoldRegion.swift
//  Purgio
//
//  Created by ZeynepMüslim on 06.10.2026.
//

import UIKit

/// The iPhone Duo fold (the "division" reserved region) as a layout hint.
/// Read it on each layout pass; use it to move controls clear of the fold,
/// never to enable or disable functionality.
enum FoldRegion {

    enum Pose {
        /// No active fold: closed, fully open, or a device without one.
        case flat
        /// Vertical fold band, halves side by side.
        case book
        /// Horizontal fold band, a raised half above a flat base.
        case table
    }

    /// Frame of the active fold in `view`'s coordinate space (margins included),
    /// or nil when there is none or it doesn't cross the view.
    static func activeFold(in view: UIView) -> CGRect? {
        fold(in: view, includeInactive: false)
    }

    /// With `includeInactive`, the fold is also returned while the device is fully open.
    /// Use that for high-level choices such as where columns split, so the layout
    /// doesn't jump when the device folds.
    static func fold(in view: UIView, includeInactive: Bool) -> CGRect? {
        guard #available(iOS 27.1, *) else { return nil }
        let options: UIView.ReservedRegion.QueryOptions = includeInactive ? [.includeInactive] : []
        guard let region = view.reservedRegions(kind: .division, options: options)
                .first(where: { includeInactive || $0.isActive }),
              region.frame.intersects(view.bounds) else { return nil }
        return region.frame
    }

    /// The fold (inactive included) only when it divides `view` into two usable panes:
    /// its center line is inside the view with at least a third of the view on each side.
    /// In Split View the app ends at the fold and its margin only overlaps the window
    /// edge; that's no reason to split the content into columns.
    static func splittingFold(in view: UIView) -> CGRect? {
        guard let fold = fold(in: view, includeInactive: true) else { return nil }
        let isVertical = fold.height > fold.width
        let center = isVertical ? fold.midX : fold.midY
        let length = isVertical ? view.bounds.width : view.bounds.height
        let minimumPane = length / 3
        guard center >= minimumPane, center <= length - minimumPane else { return nil }
        return fold
    }

    static func pose(for fold: CGRect?) -> Pose {
        guard let fold = fold, !fold.isEmpty else { return .flat }
        return fold.height > fold.width ? .book : .table
    }
}

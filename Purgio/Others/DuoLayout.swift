//
//  DuoLayout.swift
//  Purgio
//
//  Created by ZeynepMüslim on 06.10.2026.
//

import UIKit

/// iPhone Duo edge rules. HomeViewController is the reference screen: when the tab bar
/// becomes a vertical rail (outer display, inner landscape), its content moves closer to
/// the rail and down to the bottom edge. Other screens match those values so every
/// screen's bottom row and trailing edge line up. See Docs/iPhone-Duo-Transformation.md.
enum DuoLayout {

    /// Home's vertical-rail padding. Positive values; apply the edge's sign at the constraint.
    enum RailPadding {
        /// From the safe area's edge next to the rail (trailing on the full display,
        /// leading in Split View on the left half).
        static let nextToRail: CGFloat = 6
        /// From the view's bottom edge (not the safe area).
        static let bottom: CGFloat = 20
        /// From the safe area's leading edge while the rail is trailing, for full-width content
        /// that would otherwise touch the device's rounded corner (wide bin button, Delete Bin
        /// grid). Not a Home value. With the rail leading, the far edge keeps its standard padding.
        static let cornerClearance: CGFloat = 18
    }

    /// Same check Home uses: the tab bar is taller than wide.
    static func isVerticalRail(_ tabBarController: UITabBarController?) -> Bool {
        guard let tabBar = tabBarController?.tabBar else { return false }
        return tabBar.bounds.height > tabBar.bounds.width
    }

    enum RailSide {
        case left, right
    }

    /// Physical side of the vertical rail in `view`, or nil without one. The rail goes on
    /// the app's outer edge, so in Split View on the left half it's on the left.
    static func railSide(_ tabBarController: UITabBarController?, in view: UIView) -> RailSide? {
        guard isVerticalRail(tabBarController), let tabBar = tabBarController?.tabBar else { return nil }
        let railFrame = tabBar.convert(tabBar.bounds, to: view)
        return railFrame.midX < view.bounds.midX ? .left : .right
    }

    enum RailEdge {
        case leading, trailing
    }

    /// `railSide` as a layout edge of `view`, for leading/trailing constraints.
    static func railEdge(_ tabBarController: UITabBarController?, in view: UIView) -> RailEdge? {
        guard let side = railSide(tabBarController, in: view) else { return nil }
        let isLeftToRight = view.effectiveUserInterfaceLayoutDirection == .leftToRight
        return (side == .left) == isLeftToRight ? .leading : .trailing
    }
}

/// Leading/trailing/bottom constraints for one view that switch between the screen's own
/// standard padding and Home's vertical-rail padding: 6pt next to the rail, whichever side
/// it's on, and the standard padding across from it.
final class DuoEdgeConstraints {

    private let leading: NSLayoutConstraint
    private let trailing: NSLayoutConstraint
    private let standardLeading: CGFloat
    private let standardTrailing: CGFloat
    private let railTrailingFarLeading: CGFloat?
    private let safeAreaBottom: NSLayoutConstraint?
    private let railBottom: NSLayoutConstraint?

    /// All distances are positive; the constraints apply the edge's sign.
    /// - Parameters:
    ///   - standardLeading: distance from the safe area's leading edge.
    ///   - standardTrailing: distance from the safe area's trailing edge.
    ///   - railTrailingFarLeading: leading distance while the rail is trailing, when it
    ///     differs from the standard one (`RailPadding.cornerClearance`).
    ///   - standardBottom: distance from the safe area's bottom edge, or nil
    ///     when this view's bottom is laid out by something else.
    ///   - railBottomOffset: extra distance above the rail bottom, for views that sit
    ///     above the screen's bottom row instead of on Home's baseline.
    init(
        item: UIView, in view: UIView, standardLeading: CGFloat, standardTrailing: CGFloat,
        railTrailingFarLeading: CGFloat? = nil, standardBottom: CGFloat? = nil, railBottomOffset: CGFloat = 0
    ) {
        let safeArea = view.safeAreaLayoutGuide
        leading = item.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: standardLeading)
        trailing = item.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -standardTrailing)
        self.standardLeading = standardLeading
        self.standardTrailing = standardTrailing
        self.railTrailingFarLeading = railTrailingFarLeading

        if let standardBottom = standardBottom {
            safeAreaBottom = item.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -standardBottom)
            railBottom = item.bottomAnchor.constraint(
                equalTo: view.bottomAnchor, constant: -(DuoLayout.RailPadding.bottom + railBottomOffset))
        } else {
            safeAreaBottom = nil
            railBottom = nil
        }
    }

    /// The standard-layout constraints; activate them with the screen's other constraints.
    var initialConstraints: [NSLayoutConstraint] {
        [leading, trailing] + [safeAreaBottom].compactMap { $0 }
    }

    func update(railEdge: DuoLayout.RailEdge?) {
        let leadingConstant: CGFloat
        let trailingConstant: CGFloat
        switch railEdge {
        case nil:
            leadingConstant = standardLeading
            trailingConstant = -standardTrailing
        case .trailing:
            leadingConstant = railTrailingFarLeading ?? standardLeading
            trailingConstant = -DuoLayout.RailPadding.nextToRail
        case .leading:
            leadingConstant = DuoLayout.RailPadding.nextToRail
            trailingConstant = -standardTrailing
        }
        if leading.constant != leadingConstant { leading.constant = leadingConstant }
        if trailing.constant != trailingConstant { trailing.constant = trailingConstant }

        let isVerticalRail = railEdge != nil
        guard let safeAreaBottom = safeAreaBottom, let railBottom = railBottom,
              railBottom.isActive != isVerticalRail else { return }
        // Deactivate before activating to avoid a temporary conflict
        if isVerticalRail {
            safeAreaBottom.isActive = false
            railBottom.isActive = true
        } else {
            railBottom.isActive = false
            safeAreaBottom.isActive = true
        }
    }
}

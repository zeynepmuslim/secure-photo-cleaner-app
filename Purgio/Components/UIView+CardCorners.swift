//
//  UIView+CardCorners.swift
//  Purgio
//
//  Created by ZeynepMüslim on 07.10.2026.
//

import UIKit

extension UIView {

    /// Farthest a card's bottom corner can sit from the window's bottom corner and still
    /// count as "in" it. Content keeps 20pt from the bottom and at most 20pt from the far
    /// side; the side next to the rail is the rail's width plus 6pt away, so it never matches.
    private static let deviceCornerTolerance: CGFloat = 30

    /// Standard card radius on every corner. With `followingDeviceCorner` (iPhone Duo
    /// vertical rail), a bottom corner that sits in the window's bottom corner follows the
    /// device curve instead. That corner is container-concentric (UIKit's
    /// `ConcentricRectangle`) without a minimum: the outer display's radius is below 16,
    /// so a minimum would override it, and far corners would shrink toward 0. That's why
    /// only the one corner is concentric. Call after the card's frame is laid out.
    func updateCardCorners(followingDeviceCorner: Bool) {
        let radius = GeneralConstants.CornerRadius.card
        guard #available(iOS 26.0, *) else {
            layer.cornerRadius = radius
            return
        }

        let corner = followingDeviceCorner ? windowBottomCorner() : nil
        let standard = UICornerRadius.fixed(radius)
        let concentric = UICornerRadius.containerConcentric()
        cornerConfiguration = .corners(
            topLeftRadius: standard,
            topRightRadius: standard,
            bottomLeftRadius: corner == .bottomLeft ? concentric : standard,
            bottomRightRadius: corner == .bottomRight ? concentric : standard)
    }

    /// The window's bottom corner this view sits in, if any (physical sides, so RTL needs nothing).
    private func windowBottomCorner() -> UIRectCorner? {
        guard let window = window else { return nil }
        let frame = convert(bounds, to: window)
        let tolerance = Self.deviceCornerTolerance
        guard window.bounds.maxY - frame.maxY <= tolerance else { return nil }
        if frame.minX - window.bounds.minX <= tolerance { return .bottomLeft }
        if window.bounds.maxX - frame.maxX <= tolerance { return .bottomRight }
        return nil
    }
}

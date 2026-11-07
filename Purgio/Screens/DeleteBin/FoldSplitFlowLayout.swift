//
//  FoldSplitFlowLayout.swift
//  Purgio
//
//  Created by ZeynepMüslim on 08.11.2026.
//

import UIKit

/// Flow layout whose columns can split in two around the iPhone Duo fold. A flow layout
/// spaces every column the same, so items from `splitX` on move right by `extraGap`: the
/// gap at the fold becomes the regular spacing plus `extraGap`. The section's right inset
/// must leave room for the shift.
final class FoldSplitFlowLayout: UICollectionViewFlowLayout {

    /// Collection view x where the right half starts (physical), or nil for no split.
    var splitX: CGFloat?
    /// Space added to the gap at `splitX`.
    var extraGap: CGFloat = 0

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let splitX = splitX, extraGap > 0 else { return super.layoutAttributesForElements(in: rect) }
        // Items that move into `rect` start up to `extraGap` to its left
        let queryRect = CGRect(x: rect.minX - extraGap, y: rect.minY,
                               width: rect.width + extraGap, height: rect.height)
        return super.layoutAttributesForElements(in: queryRect)?.compactMap { attributes in
            let shifted = shift(attributes, splitX: splitX)
            return shifted.frame.intersects(rect) ? shifted : nil
        }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = super.layoutAttributesForItem(at: indexPath) else { return nil }
        guard let splitX = splitX, extraGap > 0 else { return attributes }
        return shift(attributes, splitX: splitX)
    }

    private func shift(_ attributes: UICollectionViewLayoutAttributes, splitX: CGFloat) -> UICollectionViewLayoutAttributes {
        guard attributes.representedElementCategory == .cell, attributes.frame.minX >= splitX,
              let copy = attributes.copy() as? UICollectionViewLayoutAttributes else { return attributes }
        copy.frame.origin.x += extraGap
        return copy
    }
}

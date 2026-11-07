//
//  SkeletonGridView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

/// Square shimmer cells in the same grid as the bin's collection view. Rows fill the
/// view's height; set `columns` to match the real grid when its width changes.
final class SkeletonGridView: UIView {

    private let spacing: CGFloat = 2
    private var skeletonCells: [SkeletonCellView] = []
    private var isAnimating = false

    var columns: Int {
        didSet {
            if columns != oldValue { setNeedsLayout() }
        }
    }

    init(columns: Int = 3) {
        self.columns = max(1, columns)
        super.init(frame: .zero)
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let columnCount = CGFloat(max(1, columns))
        let side = floor((bounds.width - (columnCount - 1) * spacing) / columnCount)
        guard side > 0 else { return }
        // Flow layout spreads the leftover of the floored side across a row's gaps,
        // so the last column ends on the same edge as the real grid
        let columnSpacing = columnCount > 1
            ? (bounds.width - columnCount * side) / (columnCount - 1)
            : spacing
        let rows = Int(ceil((bounds.height + spacing) / (side + spacing)))
        let cellCount = rows * Int(columnCount)

        while skeletonCells.count < cellCount {
            let cell = SkeletonCellView()
            addSubview(cell)
            skeletonCells.append(cell)
            if isAnimating { cell.startShimmerAnimation() }
        }
        while skeletonCells.count > cellCount {
            let cell = skeletonCells.removeLast()
            cell.stopShimmerAnimation()
            cell.removeFromSuperview()
        }

        for (index, cell) in skeletonCells.enumerated() {
            let row = CGFloat(index / Int(columnCount))
            let column = CGFloat(index % Int(columnCount))
            cell.frame = CGRect(
                x: column * (side + columnSpacing), y: row * (side + spacing), width: side, height: side)
        }
    }

    func startAnimating() {
        isAnimating = true
        skeletonCells.forEach { $0.startShimmerAnimation() }
    }

    func stopAnimating() {
        isAnimating = false
        skeletonCells.forEach { $0.stopShimmerAnimation() }
    }

    func fadeOut(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.3,
            animations: {
                self.alpha = 0
            }
        ) { _ in
            self.stopAnimating()
            self.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Skeleton Grid") {
        let grid = SkeletonGridView(columns: 3)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.widthAnchor.constraint(equalToConstant: 300),
            grid.heightAnchor.constraint(equalToConstant: 400)
        ])
        return grid
    }
#endif

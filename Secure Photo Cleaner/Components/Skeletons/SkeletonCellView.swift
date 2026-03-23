//
//  SkeletonCellView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonCellView: UIView {
    private let shimmerLayer = ShimmerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shimmerLayer.frame = bounds
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && !shimmerLayer.isAnimating {
            startShimmerAnimation()
        }
    }

    private func setupUI() {
        backgroundColor = UIColor.systemGray5
        clipsToBounds = true
        layer.addSublayer(shimmerLayer)
    }

    func startShimmerAnimation() {
        shimmerLayer.startAnimating()
    }

    func stopShimmerAnimation() {
        shimmerLayer.stopAnimating()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Skeleton Cell") {
        let cell = SkeletonCellView()
        cell.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cell.widthAnchor.constraint(equalToConstant: 100),
            cell.heightAnchor.constraint(equalToConstant: 100)
        ])
        return cell
    }
#endif

//
//  SkeletonStatsView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonStatsView: UIView {

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
        layer.cornerRadius = 6
        clipsToBounds = true
        layer.addSublayer(shimmerLayer)
    }

    func startShimmerAnimation() {
        shimmerLayer.startAnimating()
    }

    func stopShimmerAnimation() {
        shimmerLayer.stopAnimating()
    }

    func fadeOut(completion: (() -> Void)? = nil) {
        UIView.animate(
            withDuration: 0.2,
            animations: {
                self.alpha = 0
            }
        ) { _ in
            self.stopShimmerAnimation()
            self.removeFromSuperview()
            completion?()
        }
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Skeleton Stats") {
        let stats = SkeletonStatsView()
        stats.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stats.widthAnchor.constraint(equalToConstant: 200),
            stats.heightAnchor.constraint(equalToConstant: 20)
        ])
        return stats
    }
#endif

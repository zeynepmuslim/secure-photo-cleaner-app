//
//  SkeletonCardView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonCardView: UIView {

    private let shimmerLayer: ShimmerLayer = {
        let layer = ShimmerLayer()
        layer.cornerRadius = 16
        return layer
    }()

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
        if shimmerLayer.isAnimating {
            shimmerLayer.stopAnimating()
            shimmerLayer.startAnimating()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startShimmerAnimation()
        } else {
            stopShimmerAnimation()
        }
    }

    private func setupUI() {
        backgroundColor = .reviewCardBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.15
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
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
            withDuration: 0.3,
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
    #Preview("Skeleton Card") {
        let card = SkeletonCardView()
        card.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: 300),
            card.heightAnchor.constraint(equalToConstant: 400)
        ])
        return card
    }
#endif

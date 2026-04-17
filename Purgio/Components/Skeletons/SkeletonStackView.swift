//
//  SkeletonStackView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.02.2026.
//

import UIKit

final class SkeletonStackView: UIView {

    private let skeletonCard = SkeletonCardView()

    init() {
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        skeletonCard.translatesAutoresizingMaskIntoConstraints = false
        addSubview(skeletonCard)

        NSLayoutConstraint.activate([
            skeletonCard.topAnchor.constraint(equalTo: topAnchor),
            skeletonCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            skeletonCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            skeletonCard.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    func startAnimating() {
        skeletonCard.startShimmerAnimation()
    }

    func stopAnimating() {
        skeletonCard.stopShimmerAnimation()
    }
    
    func fadeOut(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
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
#Preview("Skeleton Stack") {
    let stack = SkeletonStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        stack.widthAnchor.constraint(equalToConstant: 300),
        stack.heightAnchor.constraint(equalToConstant: 400)
    ])
    return stack
}
#endif

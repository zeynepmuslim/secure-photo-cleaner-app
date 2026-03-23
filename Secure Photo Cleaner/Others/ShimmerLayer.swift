//
//  ShimmerLayer.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 09.02.2026.
//

import UIKit

final class ShimmerLayer: CAGradientLayer {

    private(set) var isAnimating = false

    var baseColor: UIColor = .systemGray5 {
        didSet { updateColors() }
    }

    var highlightColor: UIColor = .systemGray4 {
        didSet { updateColors() }
    }

    static func transparent() -> ShimmerLayer {
        let layer = ShimmerLayer()
        layer.baseColor = .clear
        layer.highlightColor = UIColor.systemGray4.withAlphaComponent(0.3)
        return layer
    }

    var animationDuration: CFTimeInterval = 1.5

    override init() {
        super.init()
        setup()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let shimmer = layer as? ShimmerLayer {
            baseColor = shimmer.baseColor
            highlightColor = shimmer.highlightColor
            animationDuration = shimmer.animationDuration
            isAnimating = shimmer.isAnimating
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }


    private func setup() {
        updateColors()
        locations = [0.0, 0.5, 1.0]
        startPoint = CGPoint(x: 0.0, y: 0.5)
        endPoint = CGPoint(x: 1.0, y: 0.5)
    }

    private func updateColors() {
        colors = [baseColor.cgColor, highlightColor.cgColor, baseColor.cgColor]
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true

        let animation = CABasicAnimation(keyPath: "locations")
        animation.fromValue = [-1.0, -0.5, 0.0]
        animation.toValue = [1.0, 1.5, 2.0]
        animation.duration = animationDuration
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        add(animation, forKey: "shimmerAnimation")
    }

    func stopAnimating() {
        isAnimating = false
        removeAnimation(forKey: "shimmerAnimation")
    }
}

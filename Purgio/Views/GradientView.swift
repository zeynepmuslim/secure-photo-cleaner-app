//
//  GradientView.swift
//  CineVault
//
//  Created by Zeynep Müslim on 29.07.2025.
//

import UIKit

class GradientView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    var gradientLayer: CAGradientLayer {
        return layer as! CAGradientLayer
    }

    var colors: [UIColor] = [] {
        didSet {
            gradientLayer.colors = colors.map { $0.cgColor }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupTraitCollectionObserver()
    }

    private func setupTraitCollectionObserver() {
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: GradientView, previousTraitCollection: UITraitCollection) in
                self.gradientLayer.colors = self.colors.map { $0.cgColor }
            }
        }
    }

    var locations: [NSNumber] = [] {
        didSet {
            gradientLayer.locations = locations
        }
    }

    var startPoint: CGPoint = CGPoint(x: 0.5, y: 0.0) {
        didSet {
            gradientLayer.startPoint = startPoint
        }
    }

    var endPoint: CGPoint = CGPoint(x: 0.5, y: 1.0) {
        didSet {
            gradientLayer.endPoint = endPoint
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

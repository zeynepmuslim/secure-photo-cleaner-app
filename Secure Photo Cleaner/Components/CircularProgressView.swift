//
//  CircularProgressView.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 24.02.2026.
//

import UIKit

final class CircularProgressView: UIView {

    private let backgroundLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.textTertiary.withAlphaComponent(0.2).cgColor
        layer.lineCap = .round
        return layer
    }()
    private let progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemGreen.cgColor
        layer.lineCap = .round
        layer.strokeEnd = 0
        return layer
    }()

    private let lineWidth: CGFloat = 6

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
    }

    private func setupLayers() {
        backgroundLayer.lineWidth = lineWidth
        progressLayer.lineWidth = lineWidth

        layer.addSublayer(backgroundLayer)
        layer.addSublayer(progressLayer)
    }

    private func updatePaths() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let startAngle = -CGFloat.pi / 2
        let endAngle = startAngle + 2 * CGFloat.pi

        let path = UIBezierPath(
            arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        backgroundLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ progress: CGFloat, animated: Bool = true) {
        let clampedProgress = max(0, min(1, progress))

        if animated {
            let animation = CABasicAnimation(keyPath: "strokeEnd")
            animation.fromValue = progressLayer.strokeEnd
            animation.toValue = clampedProgress
            animation.duration = 0.4
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            progressLayer.add(animation, forKey: "progressAnimation")
        }

        progressLayer.strokeEnd = clampedProgress

        let color: UIColor
        switch clampedProgress {
        case 0 ..< 0.25: color = .systemRed
        case 0.25 ..< 0.5: color = .systemOrange
        case 0.5 ..< 0.75: color = .systemYellow
        default: color = .systemGreen
        }
        progressLayer.strokeColor = color.cgColor
    }
}

@available(iOS 17.0, *)
#Preview {
    let ring = CircularProgressView()
    ring.translatesAutoresizingMaskIntoConstraints = false
    ring.setProgress(1.2, animated: false)

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(ring)
    NSLayoutConstraint.activate([
        ring.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        ring.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ring.widthAnchor.constraint(equalToConstant: 56),
        ring.heightAnchor.constraint(equalToConstant: 56)
    ])
    return container
}

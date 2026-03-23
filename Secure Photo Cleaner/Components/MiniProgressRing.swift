//
//  MiniProgressRing.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 20.02.2026.
//

import UIKit

final class MiniProgressRing: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let lineWidth: CGFloat

    init(lineWidth: CGFloat = 1.5) {
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = UIColor.systemGray3.cgColor
        trackLayer.lineWidth = lineWidth
        trackLayer.lineCap = .round

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = UIColor.label.cgColor
        progressLayer.lineWidth = lineWidth
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0

        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            trackLayer.strokeColor = UIColor.systemGray3.cgColor
            progressLayer.strokeColor = UIColor.label.cgColor
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - lineWidth) / 2
        let path = UIBezierPath(
            arcCenter: center, radius: radius,
            startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func setProgress(_ value: CGFloat) {
        progressLayer.strokeEnd = max(0, min(1, value))
    }
}

@available(iOS 17.0, *)
#Preview {
    let stack = UIStackView()
    stack.axis = .horizontal
    stack.spacing = 16
    stack.alignment = .center
    stack.translatesAutoresizingMaskIntoConstraints = false

    let percents: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
    for p in percents {
        let ring = MiniProgressRing()
        ring.translatesAutoresizingMaskIntoConstraints = false
        ring.widthAnchor.constraint(equalToConstant: 20).isActive = true
        ring.heightAnchor.constraint(equalToConstant: 20).isActive = true
        ring.setProgress(p)
        stack.addArrangedSubview(ring)
    }

    let container = UIView()
    container.backgroundColor = .mainBackground
    container.addSubview(stack)
    NSLayoutConstraint.activate([
        stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
        stack.centerYAnchor.constraint(equalTo: container.centerYAnchor)
    ])
    return container
}

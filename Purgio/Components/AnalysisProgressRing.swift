//
//  AnalysisProgressRing.swift
//  Purgio
//
//  Created by ZeynepMüslim on 9.02.2026.
//

import UIKit

final class AnalysisProgressRing: UIView {

    private let trackLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemGray5.cgColor
        layer.lineWidth = 2.5
        layer.lineCap = .round
        return layer
    }()
    
    private let progressLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.clear.cgColor
        layer.strokeColor = UIColor.systemBlue.cgColor
        layer.lineWidth = 2.5
        layer.lineCap = .round
        layer.strokeEnd = 0
        return layer
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            trackLayer.strokeColor = UIColor.systemGray5.cgColor
            progressLayer.strokeColor = UIColor.systemBlue.cgColor
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = (min(bounds.width, bounds.height) - trackLayer.lineWidth) / 2
        let path = UIBezierPath(
            arcCenter: center,
            radius: radius,
            startAngle: -.pi / 2,
            endAngle: 3 * .pi / 2,
            clockwise: true
        )
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    func startIndeterminate() {
        progressLayer.strokeEnd = 0.25
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = 2 * Double.pi
        rotation.duration = 0.8
        rotation.repeatCount = .infinity
        layer.add(rotation, forKey: "indeterminate")
    }

    func setProgress(_ value: CGFloat) {
        layer.removeAnimation(forKey: "indeterminate")
        progressLayer.strokeEnd = value
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Loading", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let view = AnalysisProgressRing()
            view.startIndeterminate()
            return view
        }
        .frame(width: 50, height: 50)
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Progress 25%", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let view = AnalysisProgressRing()
            view.setProgress(0.25)
            return view
        }
        .frame(width: 50, height: 50)
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Progress 50%", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let view = AnalysisProgressRing()
            view.setProgress(0.50)
            return view
        }
        .frame(width: 50, height: 50)
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Progress 75%", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let view = AnalysisProgressRing()
            view.setProgress(0.75)
            return view
        }
        .frame(width: 50, height: 50)
        .padding()
    }

    @available(iOS 17.0, *)
    private struct UIViewPreview<View: UIView>: UIViewRepresentable {
        let makeView: () -> View

        func makeUIView(context: Context) -> View {
            makeView()
        }

        func updateUIView(_ uiView: View, context: Context) {}
    }
#endif

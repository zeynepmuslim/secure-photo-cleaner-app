//
//  SoapBubble.swift
//  Purgio
//
//  Created by ZeynepMüslim on 19.04.2026.
//

import CoreMotion
import UIKit

private enum BubbleConstants {
    static let pointCount: Int = 10
    static let tension: CGFloat = 1.0 / 6.0   // Catmull-Rom → cubic bezier calcs
    static let morphDuration: Double = 5.0
    static let floatDuration: Double = 3.4
    static let floatAmplitude: CGFloat = 6.0
    static let rotateDuration: Double = 20.0
    static let colorDuration: Double = 7.0
    
    static let logoSizeRatio: CGFloat = 0.26
    static let photoSizeRatio: CGFloat = 0.14
    static let orbitRadiusRatio: CGFloat = 0.72
    
    static let tiltTranslation: CGFloat = 20
    static let tiltClampAngle: CGFloat = 0.5
    
    static let tiltUpdateInterval: TimeInterval = 1.0 / 60.0
    static let morphKey  = "bubbleMorph"
    static let floatKey  = "bubbleFloat"
    static let rotateKey = "bubbleRotate"
    static let colorKey  = "bubbleColor"
    static let iridescenceColors: [CGColor] = [
        UIColor(red: 0.55, green: 0.90, blue: 0.95, alpha: 1).cgColor,
        UIColor(red: 0.75, green: 0.65, blue: 0.95, alpha: 1).cgColor,
        UIColor(red: 0.60, green: 0.92, blue: 0.78, alpha: 1).cgColor,
        UIColor(red: 0.95, green: 0.70, blue: 0.80, alpha: 1).cgColor,
        UIColor(red: 0.70, green: 0.85, blue: 0.95, alpha: 1).cgColor,
        UIColor(red: 0.55, green: 0.90, blue: 0.95, alpha: 1).cgColor,
    ]
}

private func randomKeyframes(count: Int) -> [[CGFloat]] {
    (0..<count).map { _ in
        var deltas = (0..<BubbleConstants.pointCount).map { _ in
            CGFloat.random(in: -0.03...0.03)
        }
        let mean = deltas.reduce(0, +) / CGFloat(deltas.count)
        deltas = deltas.map { $0 - mean }
        return deltas.map { 1.0 + $0 }
    }
}

final class SoapBubble: UIView {

    private let containerLayer: CALayer = {
        let layer = CALayer()
        return layer
    }()

    private let bubbleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.white.withAlphaComponent(0.06).cgColor
        layer.lineWidth = 2.0
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }()
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(named: "logo")
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var photoImageViews: [UIImageView] = []

    private let motionManager = CMMotionManager()

    var borderColor: UIColor = .white {
        didSet { bubbleLayer.strokeColor = borderColor.cgColor }
    }

    var lineWidth: CGFloat = 2.0 {
        didSet { bubbleLayer.lineWidth = lineWidth }
    }

    var iridescenceEnabled: Bool = true
    var iridescenceColors: [CGColor] = BubbleConstants.iridescenceColors

    var onPhotoTapped: ((UIImage) -> Void)?

    /// When `true`, animations start automatically in `didMoveToWindow`.
    /// Set to `false` if the parent controls animation timing via `startAnimating()`.
    var autoStartsAnimating: Bool = true

    var fillEnabled: Bool = true {
        didSet {
            bubbleLayer.fillColor = fillEnabled
                ? UIColor.white.withAlphaComponent(0.06).cgColor
                : UIColor.clear.cgColor
        }
    }

    private(set) var isAnimating: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        containerLayer.frame = bounds
        bubbleLayer.frame = bounds

        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        bubbleLayer.path = makeBlobPath(radii: randomKeyframes(count: 1)[0], radius: radius, center: center)

        layoutPhotoOrbit()

        if isAnimating {
            stopAnimating()
            startAnimating()
        }
    }

    private func layoutPhotoOrbit() {
        guard bounds.width > 0 else { return }
        let diameter = min(bounds.width, bounds.height)
        let orbitRadius = diameter / 2 * BubbleConstants.orbitRadiusRatio
        let photoSize = diameter * BubbleConstants.photoSizeRatio
        let cx = bounds.midX
        let cy = bounds.midY

        for (index, iv) in photoImageViews.enumerated() {
            let angle = (2.0 * .pi / 7.0) * CGFloat(index) - .pi / 2.0
            let x = cx + cos(angle) * orbitRadius - photoSize / 2.0
            let y = cy + sin(angle) * orbitRadius - photoSize / 2.0
            iv.frame = CGRect(x: x, y: y, width: photoSize, height: photoSize)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            if !iridescenceEnabled {
                bubbleLayer.strokeColor = borderColor.cgColor
            }
            bubbleLayer.fillColor = fillEnabled
                ? UIColor.white.withAlphaComponent(0.06).cgColor
                : UIColor.clear.cgColor
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard autoStartsAnimating else { return }
        if window != nil {
            startAnimating()
        } else {
            stopAnimating()
        }
    }

    private func setupUI() {
        backgroundColor = .clear
        bubbleLayer.strokeColor = borderColor.cgColor
        layer.addSublayer(containerLayer)
        containerLayer.addSublayer(bubbleLayer)

        addSubview(logoImageView)

        for i in 1...7 {
            let imageView = UIImageView()
            imageView.image = UIImage(named: "photo\(i)")
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 8
            imageView.translatesAutoresizingMaskIntoConstraints = true
            imageView.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(handlePhotoTap(_:)))
            imageView.addGestureRecognizer(tap)
            photoImageViews.append(imageView)
            addSubview(imageView)
        }
    }

    @objc private func handlePhotoTap(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView,
              let index = photoImageViews.firstIndex(of: imageView) else { return }
        let largeName = "photo\(index + 1)_large"
        let fallback = imageView.image
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let large = UIImage(named: largeName) ?? fallback
            DispatchQueue.main.async {
                guard let self, let image = large else { return }
                self.onPhotoTapped?(image)
            }
        }
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoImageView.widthAnchor.constraint(equalTo: widthAnchor,
                                                   multiplier: BubbleConstants.logoSizeRatio),
            logoImageView.heightAnchor.constraint(equalTo: logoImageView.widthAnchor),
        ])
    }

    // MARK: - Path Building

    private func makeBlobPath(radii: [CGFloat], radius: CGFloat, center: CGPoint) -> CGPath {
        let n = BubbleConstants.pointCount
        let t = BubbleConstants.tension

        var pts = [CGPoint]()
        pts.reserveCapacity(n)
        for i in 0..<n {
            let angle = (CGFloat(i) / CGFloat(n)) * 2 * .pi - (.pi / 2)
            let r = radius * radii[i]
            pts.append(CGPoint(
                x: center.x + cos(angle) * r,
                y: center.y + sin(angle) * r
            ))
        }
        
        let path = UIBezierPath()
        path.move(to: pts[0])
        for i in 0..<n {
            let p0 = pts[(i - 1 + n) % n]
            let p1 = pts[i]
            let p2 = pts[(i + 1) % n]
            let p3 = pts[(i + 2) % n]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * t,
                y: p1.y + (p2.y - p0.y) * t
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * t,
                y: p2.y - (p3.y - p1.y) * t
            )
            path.addCurve(to: p2, controlPoint1: cp1, controlPoint2: cp2)
        }
        path.close()
        return path.cgPath
    }

    private func buildAllPaths(radius: CGFloat, center: CGPoint) -> [CGPath] {
        let keyframes = randomKeyframes(count: 10)
        var paths = keyframes.map { makeBlobPath(radii: $0, radius: radius, center: center) }
        
        // Append first frame at the end so the loop interpolates seamlessly back to start.
        paths.append(paths[0])
        return paths
    }

    // MARK: - Animation Building
    private func buildMorphAnimation(paths: [CGPath]) -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: "path")
        anim.values = paths
        anim.duration = BubbleConstants.morphDuration
        anim.repeatCount = .infinity
        anim.calculationMode = .cubic
        anim.timingFunctions = Array(
            repeating: CAMediaTimingFunction(name: .easeInEaseOut),
            count: paths.count - 1
        )
        anim.fillMode = .both
        anim.isRemovedOnCompletion = false
        return anim
    }

    private func buildFloatAnimation() -> CAKeyframeAnimation {
        let baseY = containerLayer.frame.midY
        let amplitude = BubbleConstants.floatAmplitude
        let steps = 20
        let values: [CGFloat] = (0...steps).map { i in
            let angle = (Double(i) / Double(steps)) * 2 * .pi
            return baseY + amplitude * CGFloat(sin(angle))
        }
        let anim = CAKeyframeAnimation(keyPath: "position.y")
        anim.values = values
        anim.duration = BubbleConstants.floatDuration
        anim.repeatCount = .infinity
        anim.calculationMode = .cubicPaced
        anim.fillMode = .both
        anim.isRemovedOnCompletion = false
        return anim
    }

    private func buildRotationAnimation() -> CABasicAnimation {
        let anim = CABasicAnimation(keyPath: "transform.rotation.z")
        anim.fromValue = 0.0
        anim.toValue   = 2.0 * Double.pi
        anim.duration = BubbleConstants.rotateDuration
        anim.repeatCount = .infinity
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.fillMode = .both
        anim.isRemovedOnCompletion = false
        return anim
    }

    private func buildColorAnimation() -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: "strokeColor")
        anim.values = iridescenceColors
        anim.duration = BubbleConstants.colorDuration
        anim.repeatCount = .infinity
        anim.calculationMode = .linear
        anim.fillMode = .both
        anim.isRemovedOnCompletion = false
        return anim
    }

    // MARK: - Public Control
    func startAnimating() {
        guard !isAnimating, bounds.width > 0 else { return }
        isAnimating = true

        let radius = min(bounds.width, bounds.height) / 2
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let paths = buildAllPaths(radius: radius, center: center)

        bubbleLayer.add(buildMorphAnimation(paths: paths), forKey: BubbleConstants.morphKey)
        containerLayer.add(buildFloatAnimation(),           forKey: BubbleConstants.floatKey)
        containerLayer.add(buildRotationAnimation(),        forKey: BubbleConstants.rotateKey)

        if iridescenceEnabled {
            bubbleLayer.add(buildColorAnimation(), forKey: BubbleConstants.colorKey)
        }

        addLogoPulse()
        addPhotoFloatingAnimations()
        startTiltTracking()
    }

    func stopAnimating() {
        guard isAnimating else { return }
        isAnimating = false
        bubbleLayer.removeAnimation(forKey: BubbleConstants.morphKey)
        bubbleLayer.removeAnimation(forKey: BubbleConstants.colorKey)
        containerLayer.removeAnimation(forKey: BubbleConstants.floatKey)
        containerLayer.removeAnimation(forKey: BubbleConstants.rotateKey)

        logoImageView.layer.removeAnimation(forKey: "logoPulse")
        for (index, iv) in photoImageViews.enumerated() {
            iv.layer.removeAnimation(forKey: "float_\(index)")
            iv.layer.removeAnimation(forKey: "rotate_\(index)")
        }

        stopTiltTracking()
    }

    // MARK: - Tilt Tracking
    private func startTiltTracking() {
        guard motionManager.isDeviceMotionAvailable,
              !motionManager.isDeviceMotionActive else { return }
        motionManager.deviceMotionUpdateInterval = BubbleConstants.tiltUpdateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            let clamp = BubbleConstants.tiltClampAngle
            let roll  = max(-clamp, min(clamp, CGFloat(motion.attitude.roll)))
            let pitch = max(-clamp, min(clamp, CGFloat(motion.attitude.pitch)))
            let dx = (roll  / clamp) * BubbleConstants.tiltTranslation
            let dy = (pitch / clamp) * BubbleConstants.tiltTranslation
            self.transform = CGAffineTransform(translationX: dx, y: dy)
        }
    }

    private func stopTiltTracking() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.transform = .identity
        }
    }

    deinit {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
    }

    // MARK: - Content Animations
    private func addLogoPulse() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.05
        pulse.duration = 1.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        logoImageView.layer.add(pulse, forKey: "logoPulse")
    }

    private func addPhotoFloatingAnimations() {
        let amplitude: CGFloat = 8.0
        let baseDurations: [Double] = [2.4, 3.1, 2.8, 3.5, 2.2, 3.8, 2.6]

        for (index, iv) in photoImageViews.enumerated() {
            let duration = baseDurations[index % baseDurations.count]
            let phaseOffset = (.pi / 7.0) * Double(index)
            let baseY = iv.layer.position.y

            let steps = 20
            var values: [CGFloat] = []
            for step in 0...steps {
                let t = (Double(step) / Double(steps)) * 2.0 * .pi + phaseOffset
                values.append(baseY + amplitude * CGFloat(sin(t)))
            }

            let floatAnim = CAKeyframeAnimation(keyPath: "position.y")
            floatAnim.values = values
            floatAnim.duration = duration
            floatAnim.repeatCount = .infinity
            floatAnim.calculationMode = .cubicPaced
            iv.layer.add(floatAnim, forKey: "float_\(index)")

            let rotAnim = CABasicAnimation(keyPath: "transform.rotation.z")
            rotAnim.fromValue = -5.0 * Double.pi / 180.0
            rotAnim.toValue   =  5.0 * Double.pi / 180.0
            rotAnim.duration  = duration * 1.3
            rotAnim.autoreverses = true
            rotAnim.repeatCount  = .infinity
            rotAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            iv.layer.add(rotAnim, forKey: "rotate_\(index)")
        }
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Default", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let bubble = SoapBubble()
            return bubble
        }
        .frame(width: 120, height: 120)
        .background(Color.black)
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Large – no iridescence", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let bubble = SoapBubble()
            bubble.iridescenceEnabled = false
            bubble.borderColor = .systemBlue
            bubble.lineWidth = 3.0
            return bubble
        }
        .frame(width: 280, height: 280)
        .background(Color.black)
        .padding()
    }

    @available(iOS 17.0, *)
    #Preview("Small – no fill", traits: .sizeThatFitsLayout) {
        UIViewPreview {
            let bubble = SoapBubble()
            bubble.fillEnabled = false
            bubble.lineWidth = 1.5
            return bubble
        }
        .frame(width: 250, height: 250)
        .background(Color(UIColor.systemIndigo))
        .padding()
    }

    @available(iOS 17.0, *)
    private struct UIViewPreview<View: UIView>: UIViewRepresentable {
        let makeView: () -> View
        func makeUIView(context: Context) -> View { makeView() }
        func updateUIView(_ uiView: View, context: Context) {}
    }
#endif

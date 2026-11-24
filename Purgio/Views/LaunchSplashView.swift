//
//  LaunchSplashView.swift
//  Purgio
//
//  Created by Zeynep Müslim on 24.11.2026.
//

import UIKit

/// The animated launch splash (board `Launch-R4-Wordmark`, R4·C "Letter by letter").
/// Its first frame matches `LaunchScreen.storyboard`: the icon alone, 80pt wide, centered on the screen.
/// Both center on the view, not the safe area: the system's launch screen doesn't get the iPhone Duo's
/// side insets (the cover's status column, the inner display's camera strip), so a safe-area center
/// would land elsewhere. The icon and word (about 250pt) still clear those strips.
final class LaunchSplashView: UIView {

    // MARK: - Layout

    private enum Layout {
        static let logoWidth: CGFloat = 80
        static let artboardSize = CGSize(width: 610, height: 420)
        static let wordGap: CGFloat = 14
        static let wordFontSize: CGFloat = 44
        static let wordKerning: CGFloat = -0.8
        static let letterRise: CGFloat = 16
        // The sparkles' centers on the artboard, measured from the exported layers.
        static let largeSparklePivot = CGPoint(x: 426, y: 161.5)
        static let smallSparklePivot = CGPoint(x: 543.5, y: 281.5)
    }

    private enum Timing {
        static let hold: TimeInterval = 0.15
        static let slideDuration: TimeInterval = 0.45
        static let letterDuration: TimeInterval = 0.26
        static let letterStagger: TimeInterval = 0.05
        static let largeGlintDelay: TimeInterval = 0.5
        static let smallGlintDelay: TimeInterval = 0.65
        static let glintDuration: TimeInterval = 0.4
        static let fadeOutDelay: TimeInterval = 0.95
        static let fadeOutDuration: TimeInterval = 0.3
        static let reducedWordFade: TimeInterval = 0.2
        static let reducedFadeOut: TimeInterval = 0.25
    }

    // MARK: - Views

    private let logoContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let photosView = LaunchSplashView.makeLayerView(image: .launchLogoPhotos)
    /// The big sparkle's cutout: its shape grown by the logo's gap, in the background color.
    /// It turns with the sparkle, so the gap in the photo frame follows the glint.
    private let sparkleHaloView: UIImageView = {
        let view = LaunchSplashView.makeLayerView(image: .launchLogoSparkleHalo)
        view.tintColor = .systemBackground
        return view
    }()
    private let sparkleLargeView = LaunchSplashView.makeLayerView(image: .launchLogoSparkleLarge)
    private let sparkleSmallView = LaunchSplashView.makeLayerView(image: .launchLogoSparkleSmall)

    private var logoLayerViews: [UIImageView] {
        [photosView, sparkleHaloView, sparkleLargeView, sparkleSmallView]
    }

    private let wordStack: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .lastBaseline
        // Kerning between single-letter labels lives in the stack's spacing.
        stack.spacing = Layout.wordKerning
        return stack
    }()

    private var letterLabels: [UILabel] = []
    private var logoCenterXConstraint: NSLayoutConstraint?

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private static func makeLayerView(image: UIImage?) -> UIImageView {
        let view = UIImageView(image: image)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }

    private func setupUI() {
        backgroundColor = .systemBackground
        accessibilityElementsHidden = true

        addSubview(logoContainer)
        logoLayerViews.forEach { logoContainer.addSubview($0) }

        addSubview(wordStack)
        let font = ThemeManager.Fonts.titleFont(size: Layout.wordFontSize, weight: .heavy)
        letterLabels = Strings.wordmark.map { character in
            let label = UILabel()
            label.text = String(character)
            label.font = font
            label.textColor = .label
            label.alpha = 0
            label.transform = CGAffineTransform(translationX: 0, y: Layout.letterRise)
            return label
        }
        letterLabels.forEach { wordStack.addArrangedSubview($0) }
    }

    private func setupConstraint() {
        let centerX = logoContainer.centerXAnchor.constraint(equalTo: centerXAnchor)
        logoCenterXConstraint = centerX

        var constraints: [NSLayoutConstraint] = [
            centerX,
            logoContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            logoContainer.widthAnchor.constraint(equalToConstant: Layout.logoWidth),
            logoContainer.heightAnchor.constraint(
                equalTo: logoContainer.widthAnchor,
                multiplier: Layout.artboardSize.height / Layout.artboardSize.width),

            wordStack.leadingAnchor.constraint(equalTo: logoContainer.trailingAnchor, constant: Layout.wordGap),
            wordStack.centerYAnchor.constraint(equalTo: logoContainer.centerYAnchor)
        ]
        for layer in logoLayerViews {
            constraints += [
                layer.topAnchor.constraint(equalTo: logoContainer.topAnchor),
                layer.bottomAnchor.constraint(equalTo: logoContainer.bottomAnchor),
                layer.leadingAnchor.constraint(equalTo: logoContainer.leadingAnchor),
                layer.trailingAnchor.constraint(equalTo: logoContainer.trailingAnchor)
            ]
        }
        NSLayoutConstraint.activate(constraints)
    }

    // MARK: - Animation

    /// Runs the splash once and calls `completion` after it has faded out.
    func play(completion: @escaping () -> Void) {
        layoutIfNeeded()
        // The word's width is only known after layout.
        let finalOffset = -(Layout.wordGap + wordStack.bounds.width) / 2

        if UIAccessibility.isReduceMotionEnabled {
            playReduced(finalOffset: finalOffset, completion: completion)
            return
        }

        UIView.animate(
            withDuration: Timing.slideDuration, delay: Timing.hold, options: .curveEaseOut,
            animations: {
                self.logoCenterXConstraint?.constant = finalOffset
                self.layoutIfNeeded()
            })

        for (index, label) in letterLabels.enumerated() {
            UIView.animate(
                withDuration: Timing.letterDuration,
                delay: Timing.hold + Double(index) * Timing.letterStagger,
                options: .curveEaseOut,
                animations: {
                    label.alpha = 1
                    label.transform = .identity
                })
        }

        glintLargeSparkle(after: Timing.largeGlintDelay)
        popSmallSparkle(after: Timing.smallGlintDelay)

        UIView.animate(
            withDuration: Timing.fadeOutDuration, delay: Timing.fadeOutDelay, options: .curveEaseInOut,
            animations: { self.alpha = 0 },
            completion: { _ in completion() })
    }

    private func playReduced(finalOffset: CGFloat, completion: @escaping () -> Void) {
        logoCenterXConstraint?.constant = finalOffset
        letterLabels.forEach { $0.transform = .identity }
        layoutIfNeeded()

        UIView.animate(
            withDuration: Timing.reducedWordFade, delay: Timing.hold, options: .curveEaseOut,
            animations: { self.letterLabels.forEach { $0.alpha = 1 } },
            completion: { _ in
                UIView.animate(
                    withDuration: Timing.reducedFadeOut, delay: 0, options: .curveEaseInOut,
                    animations: { self.alpha = 0 },
                    completion: { _ in completion() })
            })
    }

    /// The big sparkle grows to 1.32× while turning 45°, then lands at 1× and 90°
    /// (a 4-point star at 90° is the same shape, so it settles seamlessly).
    private func glintLargeSparkle(after delay: TimeInterval) {
        let pivot = Layout.largeSparklePivot
        let turningViews = [sparkleHaloView, sparkleLargeView]
        UIView.animateKeyframes(
            withDuration: Timing.glintDuration, delay: delay, options: .calculationModeCubic,
            animations: {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5) {
                    let transform = self.pivotTransform(pivot: pivot, scale: 1.32, angle: .pi / 4)
                    turningViews.forEach { $0.transform = transform }
                }
                UIView.addKeyframe(withRelativeStartTime: 0.5, relativeDuration: 0.5) {
                    let transform = self.pivotTransform(pivot: pivot, scale: 1, angle: .pi / 2)
                    turningViews.forEach { $0.transform = transform }
                }
            },
            completion: { _ in turningViews.forEach { $0.transform = .identity } })
    }

    /// The small sparkle pops to 1.45× and springs back.
    private func popSmallSparkle(after delay: TimeInterval) {
        let pivot = Layout.smallSparklePivot
        let half = Timing.glintDuration / 2
        UIView.animate(
            withDuration: half, delay: delay,
            usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8, options: [],
            animations: {
                self.sparkleSmallView.transform = self.pivotTransform(pivot: pivot, scale: 1.45, angle: 0)
            },
            completion: { _ in
                UIView.animate(
                    withDuration: half, delay: 0,
                    usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8, options: [],
                    animations: { self.sparkleSmallView.transform = .identity })
            })
    }

    /// Scales and turns a layer view around a point given in artboard coordinates,
    /// without moving the view: translate to the pivot, rotate and scale, translate back.
    private func pivotTransform(pivot: CGPoint, scale: CGFloat, angle: CGFloat) -> CGAffineTransform {
        let ratio = logoContainer.bounds.width / Layout.artboardSize.width
        let bounds = logoContainer.bounds
        let dx = pivot.x * ratio - bounds.midX
        let dy = pivot.y * ratio - bounds.midY
        return CGAffineTransform(translationX: dx, y: dy)
            .rotated(by: angle)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -dx, y: -dy)
    }
}

// MARK: - Strings

private enum Strings {
    static let wordmark = NSLocalizedString("launch.wordmark", comment: "App name shown on the launch splash")
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let container = UIView()
    container.backgroundColor = .systemBackground

    func playLoop() {
        let splash = LaunchSplashView()
        splash.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(splash)
        NSLayoutConstraint.activate([
            splash.topAnchor.constraint(equalTo: container.topAnchor),
            splash.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            splash.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            splash.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            splash.play {
                splash.removeFromSuperview()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { playLoop() }
            }
        }
    }
    playLoop()
    return container
}
#endif

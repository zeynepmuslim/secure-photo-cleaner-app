//
//  ProgressiveBlurView.swift
//  Purgio
//
//  Created by Zeynep Müslim on 11.11.2026.
//

import UIKit

/// Lies over a scroll view's top edge: content scrolling under it blurs and fades into the
/// background, strongest at the top edge and gone at the bottom. Touches pass through.
/// The material has a tint of its own, so the blur shows only as content scrolls under it
/// (`setContentOverlap(_:)`); at rest the view is invisible.
final class ProgressiveBlurView: UIView {

    /// The color content fades into: the background behind the scroll view
    var fadeColor: UIColor = .mainBackground {
        didSet { applyFadeColors() }
    }

    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// The blur's strength along the height: full at the top edge, easing out to none
    private let blurMaskView: GradientView = {
        let view = GradientView()
        view.colors = [1, 0.85, 0.5, 0.18, 0].map { UIColor.black.withAlphaComponent($0) }
        view.locations = [0, 0.25, 0.5, 0.75, 1]
        return view
    }()

    /// Over the blur, so the material's tint melts into the background
    private let fadeView: GradientView = {
        let view = GradientView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.locations = [0, 0.4, 1]
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear

        addSubview(blurView)
        addSubview(fadeView)
        blurView.mask = blurMaskView
        blurView.alpha = 0
        applyFadeColors()

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            fadeView.topAnchor.constraint(equalTo: topAnchor),
            fadeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fadeView.trailingAnchor.constraint(equalTo: trailingAnchor),
            fadeView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // A mask view isn't in the hierarchy, so Auto Layout can't size it
        blurMaskView.frame = blurView.bounds
    }

    /// How far content has scrolled under the view: the blur fades in over the view's height
    func setContentOverlap(_ overlap: CGFloat) {
        let height = max(bounds.height, 1)
        let alpha = min(max(overlap / height, 0), 1)
        guard blurView.alpha != alpha else { return }
        blurView.alpha = alpha
    }

    private func applyFadeColors() {
        // Opaque at the edge, so content dissolves into the background there
        fadeView.colors = [1, 0.5, 0].map { fadeColor.withAlphaComponent($0) }
    }

    // GradientView re-resolves its colors on iOS 17+; iOS 15/16 refresh them here
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) else { return }
        applyFadeColors()
    }
}

// MARK: - Preview

#if DEBUG
import SwiftUI

@available(iOS 17.0, *)
#Preview {
    let container = UIView()
    container.backgroundColor = .mainBackground
    let card = UIView()
    card.backgroundColor = .cardBackground
    card.layer.cornerRadius = GeneralConstants.CornerRadius.card
    card.layer.cornerCurve = .continuous
    card.frame = CGRect(x: 20, y: 10, width: 300, height: 80)
    container.addSubview(card)
    let blur = ProgressiveBlurView(frame: CGRect(x: 0, y: 0, width: 340, height: 48))
    container.addSubview(blur)
    return container
}
#endif

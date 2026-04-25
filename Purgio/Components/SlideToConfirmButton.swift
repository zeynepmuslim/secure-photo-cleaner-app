//
//  SlideToConfirmButton.swift
//  Purgio
//
//  Created by ZeynepMüslim on 5.04.2026.
//

import UIKit

final class SlideToConfirmButton: UIControl {

    var title: String? {
        didSet { titleLabel.text = title }
    }

    var confirmationThreshold: CGFloat = 0.85

    func reset() {
        didConfirm = false
        thumbLeadingConstraint.constant = thumbInset
        applyProgressVisuals(progress: 0)
        layoutIfNeeded()
    }

    private let controlHeight: CGFloat = 56
    private let thumbInset: CGFloat = 4
    private var thumbDiameter: CGFloat { controlHeight - thumbInset * 2 }

    private let trackView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        view.backgroundColor = .systemGray4
        return view
    }()

    private let greenOverlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        view.backgroundColor = .systemGreen
        view.alpha = 0
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = ThemeManager.Fonts.semiboldBody
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let thumbView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        return view
    }()

    private let thumbIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .center
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        imageView.image = UIImage(systemName: "chevron.right", withConfiguration: config)
        imageView.tintColor = .tipJarRed100
        return imageView
    }()

    private var thumbLeadingConstraint: NSLayoutConstraint!
    private var panStartX: CGFloat = 0
    private var didConfirm: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(trackView)
        trackView.addSubview(greenOverlayView)
        trackView.addSubview(titleLabel)
        addSubview(thumbView)
        thumbView.addSubview(thumbIconView)

        thumbLeadingConstraint = thumbView.leadingAnchor.constraint(
            equalTo: leadingAnchor, constant: thumbInset
        )

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: controlHeight),

            trackView.topAnchor.constraint(equalTo: topAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            trackView.bottomAnchor.constraint(equalTo: bottomAnchor),

            greenOverlayView.topAnchor.constraint(equalTo: trackView.topAnchor),
            greenOverlayView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            greenOverlayView.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),
            greenOverlayView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: trackView.leadingAnchor, constant: 56),
            titleLabel.trailingAnchor.constraint(equalTo: trackView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: trackView.centerYAnchor),

            thumbLeadingConstraint,
            thumbView.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbView.widthAnchor.constraint(equalToConstant: thumbDiameter),
            thumbView.heightAnchor.constraint(equalToConstant: thumbDiameter),

            thumbIconView.centerXAnchor.constraint(equalTo: thumbView.centerXAnchor),
            thumbIconView.centerYAnchor.constraint(equalTo: thumbView.centerYAnchor)
        ])
    }

    private func setupGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        thumbView.addGestureRecognizer(pan)
        thumbView.isUserInteractionEnabled = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        trackView.layer.cornerRadius = controlHeight / 2
        greenOverlayView.layer.cornerRadius = controlHeight / 2
        thumbView.layer.cornerRadius = thumbDiameter / 2
    }

    private var maxTravel: CGFloat {
        max(0, bounds.width - thumbDiameter - thumbInset * 2)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isEnabled, !didConfirm else { return }

        switch gesture.state {
        case .began:
            HapticFeedbackManager.shared.selection()
            panStartX = thumbLeadingConstraint.constant

        case .changed:
            let translation = gesture.translation(in: self).x
            let target = panStartX + translation
            let clamped = max(thumbInset, min(target, maxTravel + thumbInset))
            thumbLeadingConstraint.constant = clamped
            applyProgressVisuals(progress: currentProgress())

        case .ended, .cancelled, .failed:
            if currentProgress() >= confirmationThreshold {
                commitConfirmation()
            } else {
                snapBack()
            }

        default:
            break
        }
    }

    private func currentProgress() -> CGFloat {
        let raw = (thumbLeadingConstraint.constant - thumbInset) / max(maxTravel, 1)
        return max(0, min(raw, 1))
    }

    private func applyProgressVisuals(progress: CGFloat) {
        greenOverlayView.alpha = progress
        let thumbDisplacement = thumbLeadingConstraint.constant - thumbInset
        titleLabel.transform = CGAffineTransform(translationX: thumbDisplacement, y: 0)
        titleLabel.alpha = max(0, 1 - progress * 1.5)
    }

    private func commitConfirmation() {
        guard !didConfirm else { return }
        didConfirm = true
        HapticFeedbackManager.shared.success()

        thumbLeadingConstraint.constant = maxTravel + thumbInset
        UIView.animate(
            withDuration: 0.22,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.applyProgressVisuals(progress: 1)
                self.layoutIfNeeded()
            }
        )

        sendActions(for: .primaryActionTriggered)
    }

    private func snapBack() {
        thumbLeadingConstraint.constant = thumbInset
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.6,
            options: [.allowUserInteraction],
            animations: {
                self.applyProgressVisuals(progress: 0)
                self.layoutIfNeeded()
            }
        )
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyProgressVisuals(progress: currentProgress())
    }
}

// MARK: - SwiftUI Preview

#if DEBUG
import SwiftUI

private struct SlideToConfirmButtonPreview: UIViewRepresentable {
    let title: String

    func makeUIView(context: Context) -> SlideToConfirmButton {
        let button = SlideToConfirmButton()
        button.title = title
        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.didConfirm(_:)),
            for: .primaryActionTriggered
        )
        return button
    }

    func updateUIView(_ uiView: SlideToConfirmButton, context: Context) {
        uiView.title = title
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        @objc func didConfirm(_ sender: SlideToConfirmButton) {
            print("[Preview] Confirmed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                sender.reset()
            }
        }
    }
}

#Preview("Light") {
    VStack(spacing: 24) {
        SlideToConfirmButtonPreview(title: "Slide to Delete")
            .frame(height: 56)
        SlideToConfirmButtonPreview(title: "Slide to Confirm Tip")
            .frame(height: 56)
    }
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Dark") {
    VStack(spacing: 24) {
        SlideToConfirmButtonPreview(title: "Slide to Delete")
            .frame(height: 56)
        SlideToConfirmButtonPreview(title: "Slide to Confirm Tip")
            .frame(height: 56)
    }
    .padding()
    .background(Color(.systemBackground))
    .preferredColorScheme(.dark)
}
#endif

//
//  OnboardingViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.01.2026.
//

import UIKit

private enum Strings {
    static let title = NSLocalizedString("onboarding.title", comment: "Onboarding welcome title")
    static let subtitle = NSLocalizedString("onboarding.subtitle", comment: "Onboarding subtitle")
    static let gotIt = NSLocalizedString("onboarding.gotIt", comment: "Got it button")
    static let swipeUpTitle = NSLocalizedString("onboarding.swipeUpTitle", comment: "Swipe up instruction title")
    static let swipeUpInfo = NSLocalizedString("onboarding.swipeUpInfo", comment: "Swipe up instruction description")
    static let swipeLeftTitle = NSLocalizedString("onboarding.swipeLeftTitle", comment: "Swipe left instruction title")
    static let swipeLeftInfo = NSLocalizedString("onboarding.swipeLeftInfo", comment: "Swipe left instruction description")
    static let swipeRightTitle = NSLocalizedString("onboarding.swipeRightTitle", comment: "Swipe right instruction title")
    static let swipeRightInfo = NSLocalizedString("onboarding.swipeRightInfo", comment: "Swipe right instruction description")
}

final class OnboardingViewController: UIViewController {

    var onDismiss: (() -> Void)?

    private let titleContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let gradientContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let topGradientView: GradientView = {
        let view = GradientView()
        view.startPoint = CGPoint(x: 0.5, y: 0)
        view.endPoint = CGPoint(x: 0.5, y: 0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let leftGradientView: GradientView = {
        let view = GradientView()
        view.startPoint = CGPoint(x: 0.0, y: 0.5)
        view.endPoint = CGPoint(x: 0.5, y: 0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let rightGradientView: GradientView = {
        let view = GradientView()
        view.startPoint = CGPoint(x: 1, y: 0.5)
        view.endPoint = CGPoint(x: 0.5, y: 0.5)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.title
        let isSmallScreen = UIScreen.main.bounds.height < 700
        label.font = .systemFont(ofSize: isSmallScreen ? 22 : 28, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.subtitle
        let isSmallScreen = UIScreen.main.bounds.height < 700
        label.font = .systemFont(ofSize: isSmallScreen ? 14 : 16, weight: .medium)
        label.textColor = .textSecondary
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let swipeIconView: UIImageView = {
        let imageView = UIImageView()
        let isSmallScreen = UIScreen.main.bounds.height < 700
        let config = UIImage.SymbolConfiguration(pointSize: isSmallScreen ? 50 : 70, weight: .ultraLight)
        imageView.image = UIImage(systemName: "hand.draw", withConfiguration: config)
        imageView.tintColor = .textPrimary
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        return imageView
    }()

    private let topStack = OnboardingInfoStackView(
        iconName: "arrow.up.circle.fill",
        title: Strings.swipeUpTitle,
        info: Strings.swipeUpInfo,
        color: .yellow100
    )

    private let leftStack = OnboardingInfoStackView(
        iconName: "arrow.left.circle.fill",
        title: Strings.swipeLeftTitle,
        info: Strings.swipeLeftInfo,
        color: .red100
    )

    private let rightStack = OnboardingInfoStackView(
        iconName: "arrow.right.circle.fill",
        title: Strings.swipeRightTitle,
        info: Strings.swipeRightInfo,
        color: .green100
    )

    private let closeButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let buttonStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraint()
        setupGestures()
        presentationController?.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startPulseAnimation()
    }

    private func setupUI() {
        if #available(iOS 26.0, *) {
            view.backgroundColor = .clear
        } else {
            view.backgroundColor = .mainBackground
        }

        topGradientView.colors = [
            UIColor.yellow200.withAlphaComponent(0.7),
            UIColor.yellow200.withAlphaComponent(0.0)
        ]
        leftGradientView.colors = [
            UIColor.red200.withAlphaComponent(0.7),
            UIColor.red200.withAlphaComponent(0.0)
        ]
        rightGradientView.colors = [
            UIColor.green200.withAlphaComponent(0.7),
            UIColor.green200.withAlphaComponent(0.0)
        ]

        closeButton.configure(
            title: Strings.gotIt,
            backgroundColor: .textPrimaryReverse,
            foregroundColor: .textPrimary,
            contentInsets: NSDirectionalEdgeInsets(top: 14, leading: 32, bottom: 14, trailing: 32)
        )
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        view.addSubview(titleContainerView)
        view.addSubview(gradientContainerView)

        titleContainerView.addSubview(titleLabel)
        titleContainerView.addSubview(subtitleLabel)

        gradientContainerView.insertSubview(topGradientView, at: 0)
        gradientContainerView.insertSubview(leftGradientView, at: 0)
        gradientContainerView.insertSubview(rightGradientView, at: 0)
        gradientContainerView.addSubview(swipeIconView)
        gradientContainerView.addSubview(topStack)
        gradientContainerView.addSubview(leftStack)
        gradientContainerView.addSubview(rightStack)

        let isSmallScreen = UIScreen.main.bounds.height < 700
        if isSmallScreen {
            buttonStack.addArrangedSubview(UIView.flexibleSpacer())
            buttonStack.addArrangedSubview(closeButton)
            buttonStack.addArrangedSubview(UIView.flexibleSpacer())
            gradientContainerView.addSubview(buttonStack)
        } else {
            gradientContainerView.addSubview(closeButton)
        }
    }

    private func setupConstraint() {
        let isSmallScreen = UIScreen.main.bounds.height < 700
        let topPadding: CGFloat = isSmallScreen ? 12 : 30
        let stackSpacing: CGFloat = isSmallScreen ? 10 : 20
        let sideStackTopSpacing: CGFloat = isSmallScreen ? 30 : 60

        NSLayoutConstraint.activate([
            titleContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: topPadding),
            titleContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            gradientContainerView.topAnchor.constraint(
                equalTo: titleContainerView.bottomAnchor, constant: stackSpacing),
            gradientContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gradientContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            gradientContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: titleContainerView.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: titleContainerView.topAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainerView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleContainerView.trailingAnchor, constant: -24),
            subtitleLabel.centerXAnchor.constraint(equalTo: titleContainerView.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.bottomAnchor.constraint(equalTo: titleContainerView.bottomAnchor),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleContainerView.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: titleContainerView.trailingAnchor, constant: -24),

            topStack.centerXAnchor.constraint(equalTo: gradientContainerView.centerXAnchor),
            topStack.topAnchor.constraint(equalTo: gradientContainerView.topAnchor, constant: stackSpacing),
            topStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.7),

            leftStack.leadingAnchor.constraint(equalTo: gradientContainerView.leadingAnchor, constant: 24),
            leftStack.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: sideStackTopSpacing),
            leftStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.3),

            rightStack.trailingAnchor.constraint(equalTo: gradientContainerView.trailingAnchor, constant: -24),
            rightStack.topAnchor.constraint(equalTo: topStack.bottomAnchor, constant: sideStackTopSpacing),
            rightStack.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.3),

            swipeIconView.centerXAnchor.constraint(equalTo: gradientContainerView.centerXAnchor),
            swipeIconView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: isSmallScreen ? 0.12 : 0.15),

            topGradientView.topAnchor.constraint(equalTo: gradientContainerView.topAnchor),
            topGradientView.leadingAnchor.constraint(equalTo: gradientContainerView.leadingAnchor),
            topGradientView.trailingAnchor.constraint(equalTo: gradientContainerView.trailingAnchor),
            topGradientView.bottomAnchor.constraint(equalTo: gradientContainerView.bottomAnchor),

            leftGradientView.topAnchor.constraint(equalTo: gradientContainerView.topAnchor),
            leftGradientView.leadingAnchor.constraint(equalTo: gradientContainerView.leadingAnchor),
            leftGradientView.trailingAnchor.constraint(equalTo: gradientContainerView.trailingAnchor, constant: 80),
            leftGradientView.bottomAnchor.constraint(equalTo: gradientContainerView.bottomAnchor),

            rightGradientView.topAnchor.constraint(equalTo: gradientContainerView.topAnchor),
            rightGradientView.leadingAnchor.constraint(equalTo: gradientContainerView.leadingAnchor, constant: -80),
            rightGradientView.trailingAnchor.constraint(equalTo: gradientContainerView.trailingAnchor),
            rightGradientView.bottomAnchor.constraint(equalTo: gradientContainerView.bottomAnchor)
        ])

        if isSmallScreen {
            NSLayoutConstraint.activate([
                swipeIconView.centerYAnchor.constraint(equalTo: gradientContainerView.centerYAnchor),
                buttonStack.topAnchor.constraint(equalTo: leftStack.bottomAnchor),
                buttonStack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                buttonStack.centerXAnchor.constraint(equalTo: gradientContainerView.centerXAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                swipeIconView.centerYAnchor.constraint(equalTo: leftStack.centerYAnchor),
                closeButton.centerXAnchor.constraint(equalTo: gradientContainerView.centerXAnchor),
                closeButton.bottomAnchor.constraint(
                    equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                    constant: -GeneralConstants.Spacer.buttonBottom
                ),
                closeButton.topAnchor.constraint(
                    greaterThanOrEqualTo: leftStack.bottomAnchor,
                    constant: GeneralConstants.EdgePadding.medium
                )
            ])
        }
    }

    private func startPulseAnimation() {
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.duration = 1.5
        pulse.fromValue = 1.0
        pulse.toValue = 1.1
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        swipeIconView.layer.add(pulse, forKey: "pulse")
    }

    @objc private func closeTapped() {
        OnboardingStore.shared.hasCompletedOnboarding = true
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
        }
    }

    private func setupGestures() {
        swipeIconView.isUserInteractionEnabled = true
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        swipeIconView.addGestureRecognizer(panGesture)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)

        switch gesture.state {
        case .began, .changed:
            let iconCenter = swipeIconView.center
            let iconSize = swipeIconView.bounds.size
            let containerBounds = gradientContainerView.bounds

            let minX = -iconCenter.x + iconSize.width / 2
            let maxX = containerBounds.width - iconCenter.x - iconSize.width / 2
            let minY = -iconCenter.y + iconSize.height / 2
            let maxY = containerBounds.height - iconCenter.y - iconSize.height / 2

            let clampedX = min(max(translation.x, minX), maxX)
            let clampedY = min(max(translation.y, minY), maxY)

            swipeIconView.transform = CGAffineTransform(translationX: clampedX, y: clampedY)

            checkIntersections()

        case .ended, .cancelled:
            UIView.animate(
                withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5,
                options: .curveEaseOut
            ) {
                self.swipeIconView.transform = .identity
                self.resetStackScales()
            }

        default:
            break
        }
    }

    private func checkIntersections() {
        let iconFrame = swipeIconView.convert(swipeIconView.bounds, to: view)

        let topFrame = topStack.convert(topStack.bounds, to: view)
        if iconFrame.intersects(topFrame) {
            animateScale(for: topStack, scale: true)
        } else {
            animateScale(for: topStack, scale: false)
        }

        let leftFrame = leftStack.convert(leftStack.bounds, to: view)
        if iconFrame.intersects(leftFrame) {
            animateScale(for: leftStack, scale: true)
        } else {
            animateScale(for: leftStack, scale: false)
        }

        let rightFrame = rightStack.convert(rightStack.bounds, to: view)
        if iconFrame.intersects(rightFrame) {
            animateScale(for: rightStack, scale: true)
        } else {
            animateScale(for: rightStack, scale: false)
        }
    }

    private func animateScale(for view: UIView, scale: Bool) {
        let targetTransform = scale ? CGAffineTransform(scaleX: 1.2, y: 1.2) : .identity

        if view.transform != targetTransform {
            UIView.animate(withDuration: 0.2) {
                view.transform = targetTransform
            }
        }
    }

    private func resetStackScales() {
        topStack.transform = .identity
        leftStack.transform = .identity
        rightStack.transform = .identity
    }
}

extension OnboardingViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        OnboardingStore.shared.hasCompletedOnboarding = true
        onDismiss?()
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Light Mode") {
        let vc = OnboardingViewController()
        vc.overrideUserInterfaceStyle = .light
        return vc
    }

    @available(iOS 17.0, *)
    #Preview("Dark Mode") {
        let vc = OnboardingViewController()
        vc.overrideUserInterfaceStyle = .dark
        vc.view.backgroundColor = .black
        return vc
    }
#endif

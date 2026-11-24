//
//  OnboardingRuleRowView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 19.11.2026.
//

import UIKit

/// Sizes for one rule row; the swipe guide picks a set by the sheet's height.
struct OnboardingRuleMetrics: Equatable {
    let capsuleSize: CGSize
    let iconSize: CGFloat
    let titleSize: CGFloat
    let infoSize: CGFloat

    static let regular = OnboardingRuleMetrics(
        capsuleSize: CGSize(width: 34, height: 58), iconSize: 17, titleSize: 20, infoSize: 15)
    static let compact = OnboardingRuleMetrics(
        capsuleSize: CGSize(width: 28, height: 46), iconSize: 14, titleSize: 17, infoSize: 13)
}

/// One rule of the swipe guide: a capsule in the action's color holding its icon, then the title
/// over the info. One VoiceOver element: "title, info".
final class OnboardingRuleRowView: UIView {

    private enum Layout {
        static let capsuleToText: CGFloat = 14
        static let titleToInfo: CGFloat = 2
    }

    private let capsuleView: UIView = {
        let view = UIView()
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textColor = .onboardingSecondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let textStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Layout.titleToInfo
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private var capsuleWidth: NSLayoutConstraint?
    private var capsuleHeight: NSLayoutConstraint?
    private var iconName = ""
    private(set) var metrics: OnboardingRuleMetrics?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
        apply(metrics: .regular)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true

        capsuleView.addSubview(iconView)
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(infoLabel)
        addSubview(capsuleView)
        addSubview(textStack)
    }

    private func setupConstraint() {
        let width = capsuleView.widthAnchor.constraint(equalToConstant: 0)
        let height = capsuleView.heightAnchor.constraint(equalToConstant: 0)
        capsuleWidth = width
        capsuleHeight = height

        NSLayoutConstraint.activate([
            width, height,
            capsuleView.leadingAnchor.constraint(equalTo: leadingAnchor),
            capsuleView.centerYAnchor.constraint(equalTo: centerYAnchor),
            capsuleView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            capsuleView.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),

            iconView.centerXAnchor.constraint(equalTo: capsuleView.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: capsuleView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: Layout.capsuleToText),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])

        // Hug the taller of the capsule and the text.
        let hug = heightAnchor.constraint(equalToConstant: 0)
        hug.priority = .fittingSizeLevel
        hug.isActive = true
    }

    // MARK: - Configure

    func configure(iconName: String, title: String, info: String, color: UIColor, titleColor: UIColor, iconTint: UIColor) {
        self.iconName = iconName
        capsuleView.backgroundColor = color
        iconView.tintColor = iconTint
        titleLabel.text = title
        titleLabel.textColor = titleColor
        infoLabel.text = info
        accessibilityLabel = "\(title), \(info)"
        updateIcon()
    }

    func apply(metrics: OnboardingRuleMetrics) {
        guard metrics != self.metrics else { return }
        self.metrics = metrics
        capsuleWidth?.constant = metrics.capsuleSize.width
        capsuleHeight?.constant = metrics.capsuleSize.height
        capsuleView.layer.cornerRadius = metrics.capsuleSize.width / 2
        titleLabel.font = ThemeManager.Fonts.titleFont(size: metrics.titleSize, weight: .heavy)
        infoLabel.font = .systemFont(ofSize: metrics.infoSize, weight: .regular)
        updateIcon()
    }

    private func updateIcon() {
        guard let metrics, !iconName.isEmpty else { return }
        let config = UIImage.SymbolConfiguration(pointSize: metrics.iconSize, weight: .bold)
        iconView.image = UIImage(systemName: iconName, withConfiguration: config)
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    // MARK: - Strings

    private enum Strings {
        static let swipeUpTitle = NSLocalizedString("onboarding.swipeUpTitle", comment: "Swipe up instruction title")
        static let swipeUpInfo = NSLocalizedString("onboarding.swipeUpInfo", comment: "Swipe up instruction description")
    }

    @available(iOS 17.0, *)
    private struct OnboardingRuleRowPreview: UIViewRepresentable {
        let metrics: OnboardingRuleMetrics

        func makeUIView(context: Context) -> OnboardingRuleRowView {
            let row = OnboardingRuleRowView()
            row.configure(
                iconName: "archivebox", title: Strings.swipeUpTitle,
                info: Strings.swipeUpInfo,
                color: ThemeManager.Colors.statusYellow, titleColor: .yellow200,
                iconTint: .inkOnYellow)
            row.apply(metrics: metrics)
            return row
        }

        func updateUIView(_ uiView: OnboardingRuleRowView, context: Context) {}
    }

    @available(iOS 17.0, *)
    #Preview("Rule rows") {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingRuleRowPreview(metrics: .regular).frame(height: 70)
            OnboardingRuleRowPreview(metrics: .compact).frame(height: 56)
        }
        .padding()
    }
#endif

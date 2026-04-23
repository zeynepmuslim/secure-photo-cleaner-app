//
//  OnboardingInfoStackView.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.01.2026.
//

import UIKit

final class OnboardingInfoStackView: UIStackView {

    private let iconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.shadowOpacity = 0.6
        imageView.layer.shadowRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .textPrimary
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    init(iconName: String, title: String, info: String, color: UIColor) {
        super.init(frame: .zero)
        setupUI(iconName: iconName, title: title, info: info, color: color)
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI(iconName: String, title: String, info: String, color: UIColor) {
        axis = .vertical
        spacing = 8
        alignment = .center
        translatesAutoresizingMaskIntoConstraints = false

        let iconConfig = UIImage.SymbolConfiguration(pointSize: 26, weight: .semibold)
        iconView.image = UIImage(systemName: iconName, withConfiguration: iconConfig)
        iconView.tintColor = color
        iconView.layer.shadowColor = color.cgColor

        titleLabel.text = title
        infoLabel.text = info
        
        addArrangedSubview(iconView)
        addArrangedSubview(titleLabel)
        addArrangedSubview(infoLabel)
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Swipe Up") {
        let view = OnboardingInfoStackView(
            iconName: "arrow.up.circle.fill",
            title: NSLocalizedString("onboarding.swipeUpTitle", comment: ""),
            info: NSLocalizedString("onboarding.swipeUpInfo", comment: ""),
            color: .yellow100
        )
        return view
    }

    @available(iOS 17.0, *)
    #Preview("Swipe Left") {
        let view = OnboardingInfoStackView(
            iconName: "arrow.left.circle.fill",
            title: NSLocalizedString("onboarding.swipeLeftTitle", comment: ""),
            info: NSLocalizedString("onboarding.swipeLeftInfo", comment: ""),
            color: .red100
        )
        return view
    }
#endif

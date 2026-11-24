//
//  UIButton.Configuration+ActionSegment.swift
//  Purgio
//
//  Created by ZeynepMüslim on 10.11.2026.
//

import UIKit

extension UIButton.Configuration {

    /// A Store / Delete / Keep segment: a gray fill with the action's color on the icon only and
    /// the title under it. Used by ActionGripView (sideways) and TablePoseKeysView (table pose).
    static func actionSegment(
        title: String, systemImage: String, iconSize: CGFloat, iconColor: UIColor, cornerRadius: CGFloat
    ) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(
            systemName: systemImage,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: iconSize, weight: .semibold))
        config.imagePlacement = .top
        config.imagePadding = 8
        config.titleAlignment = .center
        config.titlePadding = 4
        var container = AttributeContainer()
        container.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        config.attributedTitle = AttributedString(title, attributes: container)
        config.baseBackgroundColor = .tertiarySystemFill
        config.baseForegroundColor = .label
        config.imageColorTransformer = UIConfigurationColorTransformer { _ in iconColor }
        config.cornerStyle = .fixed
        config.background.cornerRadius = cornerRadius
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
        return config
    }
}

//
//  HelpButton.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import UIKit

final class HelpButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        applyStyle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        applyStyle()
    }

    private func applyStyle() {
        let symbolConfig: UIImage.SymbolConfiguration
        let imageName: String
        let insets: NSDirectionalEdgeInsets

        symbolConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        imageName = "questionmark"
        insets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: imageName, withConfiguration: symbolConfig)
        config.baseForegroundColor = .textPrimary
        config.contentInsets = insets
        configuration = config
    }
}

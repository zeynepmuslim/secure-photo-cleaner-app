//
//  LuckyButton.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 26.01.2026.
//

import UIKit

final class LuckyButton: UIButton {

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
        let insets: NSDirectionalEdgeInsets

        symbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        insets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "die.face.5", withConfiguration: symbolConfig)
        config.baseForegroundColor = .textPrimary
        config.contentInsets = insets
        configuration = config
    }
}

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview("Lucky Button") {
        let button = LuckyButton()
        return button
    }
#endif

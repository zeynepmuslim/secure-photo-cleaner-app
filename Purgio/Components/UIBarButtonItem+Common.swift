//
//  UIBarButtonItem+Common.swift
//  Purgio
//
//  Created by ZeynepMüslim on 06.10.2026.
//

import UIKit

// Standard bar items with both a title and a symbol, so the system can pick the
// representation (iPhone Duo vertical bars, overflow menu). A customView item
// would stay horizontal, which is why these replaced HelpButton and LuckyButton.
extension UIBarButtonItem {

    static func helpItem(target: Any?, action: Selector) -> UIBarButtonItem {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        let item = UIBarButtonItem(
            image: UIImage(systemName: "questionmark", withConfiguration: config),
            style: .plain,
            target: target,
            action: action
        )
        item.title = CommonStrings.help
        item.tintColor = .textPrimary
        return item
    }

    static func luckyItem(title: String, target: Any?, action: Selector) -> UIBarButtonItem {
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        let item = UIBarButtonItem(
            image: UIImage(systemName: "die.face.5", withConfiguration: config),
            style: .plain,
            target: target,
            action: action
        )
        item.title = title
        item.tintColor = .textPrimary
        return item
    }
}

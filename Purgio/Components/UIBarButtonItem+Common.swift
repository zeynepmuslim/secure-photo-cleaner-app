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

    /// MonthReview's iPhone Duo table-pose Layout item: its menu picks the swipe area or the keys.
    /// The image shows the current choice.
    static func tableLayoutItem(title: String, layout: TablePoseControlsLayout, menu: UIMenu) -> UIBarButtonItem {
        let item = UIBarButtonItem(title: title, image: tableLayoutImage(for: layout), primaryAction: nil, menu: menu)
        item.tintColor = .textPrimary
        return item
    }

    static func tableLayoutImage(for layout: TablePoseControlsLayout) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        switch layout {
        case .trackpad: return UIImage(systemName: "hand.draw", withConfiguration: config)
        case .keys: return UIImage(systemName: "square.grid.2x2", withConfiguration: config)
        }
    }
}

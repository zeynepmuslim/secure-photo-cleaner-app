//
//  Constants.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.01.2026.
//

import UIKit

// MARK: - Common Strings

enum CommonStrings {
    static let remove = NSLocalizedString("common.remove", comment: "Remove button title")
    static let cancel = NSLocalizedString("common.cancel", comment: "Cancel button title")
    static let delete = NSLocalizedString("common.delete", comment: "Delete button title")
    static let ok     = NSLocalizedString("common.ok", comment: "OK button title")
    static let help   = NSLocalizedString("common.help", comment: "Help button title")
}

// MARK: - General Constants

enum GeneralConstants {

    /// Positive values; apply the edge's sign at the constraint.
    enum EdgePadding {
        static let small: CGFloat = 10
        /// Floating controls such as the bin button.
        static let medium: CGFloat = 16
        /// Screen content edges (Home, Month Review, Delete Bin edit buttons).
        static let content: CGFloat = 20
    }

    enum CornerRadius {
        static let card: CGFloat = 16
    }

    enum ButtonSize {
        
        ///30
        static let small: CGFloat = 30
        
        ///44
        static let medium: CGFloat = 44
        
        ///50
        static let mediumLarge: CGFloat = 50
        
        ///56
        static let large: CGFloat = 56
    }

    enum Spacer {
        static let buttonBottom: CGFloat = 24
    }

    /// Own-width thresholds for compact content variants (replaces window-width checks).
    /// Calibrated so 375pt iPhones keep the compact look and 390pt+ the regular one.
    enum CompactContentWidth {
        /// Full-width card inset 20pt per side (390 - 40).
        static let fullWidthCard: CGFloat = 350
        /// Half-width card in a two-up row (Home 169pt, filter grid 173pt on 390pt iPhones).
        static let halfWidthCard: CGFloat = 167
    }

    enum BulkYear {
        static let sparseYearThreshold: Int = 50
    }

}

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
}

// MARK: - General Constants

enum GeneralConstants {

    enum EdgePadding {
        static let small: CGFloat = 10
        static let medium: CGFloat = 16
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

}

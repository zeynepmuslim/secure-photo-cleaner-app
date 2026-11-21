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
    // Shared by the month hub and the finished month's split (keys kept from the hub)
    static let keep   = NSLocalizedString("filterCards.keep", comment: "Keep action label")
    static let store  = NSLocalizedString("filterCards.store", comment: "Store action label")
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
        /// Cards' inner padding and Settings rows.
        static let cardInner: CGFloat = 18
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
        /// Clearance between the iPhone Duo fold region and the content on either side of it.
        static let foldGap: CGFloat = 12
        /// Gap between a bottom row's primary button and the bin's slot beside it.
        static let bottomRowGap: CGFloat = 10
        /// Bottom clearance of a sheet's full-width primary button (the onboarding guide's Got It!).
        static let sheetButtonBottom: CGFloat = 34
        /// The same clearance on short sheets: SE, the Duo's cover display, the table pose.
        static let compactSheetButtonBottom: CGFloat = 20
    }

    /// Own-width thresholds for compact content variants (replaces window-width checks).
    /// Calibrated so 375pt iPhones keep the compact look and 390pt+ the regular one.
    enum CompactContentWidth {
        /// Full-width card inset 20pt per side (390 - 40).
        static let fullWidthCard: CGFloat = 350
        /// Half-width card in a two-up row (Home 169pt, filter grid 173pt on 390pt iPhones).
        static let halfWidthCard: CGFloat = 167
    }

    /// The Delete/Keep + Store grips beside MonthReview's card on the iPhone Duo's inner
    /// display held sideways.
    enum ActionGrip {
        /// Grip column width; the corner radius is half of it.
        static let width: CGFloat = 104
        /// Padding inside the grip and the gap between its segments.
        static let inset: CGFloat = 8
        static let storeSegmentHeight: CGFloat = 120
        /// Corner radius of the iPhone Duo table-layout trays (keys, trackpad); their segments use
        /// this minus `inset`, so the corners stay concentric.
        static let trayCornerRadius: CGFloat = 44

        /// Soft shadow under the grips and trays (black).
        enum Shadow {
            static let opacity: Float = 0.07
            static let offsetY: CGFloat = 8
            static let radius: CGFloat = 12
        }
    }

    /// The small vertical capsule that marks a color in the storage cards' legends and status.
    /// Its corner radius is half the width.
    enum LegendCapsule {
        static let width: CGFloat = 5
        static let height: CGFloat = 12
    }

    /// Spacing in the storage cards' legends.
    enum LegendGrid {
        /// Between the columns of a legend grid row.
        static let columnSpacing: CGFloat = 12
        /// Between items packed in a single legend row (Home's card).
        static let packedItemSpacing: CGFloat = 16
    }

    /// Where a bottom row holds the global bin in a slot beside its primary button.
    enum BinSlot {
        /// Phones and the Duo's cover display (the month hub, MonthReview's month-complete state).
        static let compactWidth: CGFloat = 96
    }

    /// Largest First's loading screen counts the items over these sizes ("Over 20 MB"). They are
    /// not a filter: the deck still shows every item, largest first.
    /// Decimal, as `Int64.formattedBytes()` shows them.
    enum LargeFile {
        static let photoHighlightBytes: Int64 = 20 * 1000 * 1000
        static let videoHighlightBytes: Int64 = 150 * 1000 * 1000
    }

    enum BulkYear {
        static let sparseYearThreshold: Int = 50
    }

    /// The tip jar's vertical capsules (the tier picker and the thank-you capsule).
    enum TipCapsule {
        /// Full capsule width; the corner radius is half the shorter side.
        static let width: CGFloat = 72
        /// Narrowest a tier capsule shrinks to when the sheet is short, so it stays tappable.
        static let minimumWidth: CGFloat = 44
        /// Tallest tier capsule (the large tier).
        static let maximumHeight: CGFloat = 200
        /// Between the tier columns.
        static let spacing: CGFloat = 10
    }

}

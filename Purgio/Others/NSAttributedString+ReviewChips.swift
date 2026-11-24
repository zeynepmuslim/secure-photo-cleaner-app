//
//  NSAttributedString+ReviewChips.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

extension NSAttributedString {

    private enum ReviewChipLayout {
        static let fontSize: CGFloat = 12
        static let iconPointSize: CGFloat = 12
        static let spacing: CGFloat = 10
        static let lineSpacing: CGFloat = 3
    }

    /// "trash 20  checkmark 38  archivebox 5" as one wrapping text: a chip's icon and count stay
    /// together, and a line only breaks between chips, so a count is never truncated.
    /// The icons bake their color, so build it again when the appearance changes.
    /// - Parameter hidesZeroCounts: leaves out the chips whose count is 0 (a lone "trash 0" when
    ///   all are); false always shows the three.
    static func reviewChips(
        deleted: Int, kept: Int, stored: Int, hidesZeroCounts: Bool = true, traitCollection: UITraitCollection
    ) -> NSAttributedString {
        var chips: [(systemName: String, color: UIColor, count: Int)] = [
            ("trash.fill", ThemeManager.Colors.statusRed, deleted),
            ("checkmark.circle.fill", ThemeManager.Colors.statusGreen, kept),
            ("archivebox.fill", ThemeManager.Colors.statusYellow, stored)
        ]
        if hidesZeroCounts {
            chips = chips.filter { $0.count > 0 }
            if chips.isEmpty {
                chips = [("trash.fill", ThemeManager.Colors.statusRed, 0)]
            }
        }

        let font = UIFont.monospacedDigitSystemFont(ofSize: ReviewChipLayout.fontSize, weight: .regular)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = ReviewChipLayout.lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.textSecondary,
            .paragraphStyle: paragraph
        ]
        let spaceWidth = (" " as NSString).size(withAttributes: [.font: font]).width
        var gapAttributes = textAttributes
        gapAttributes[.kern] = ReviewChipLayout.spacing - spaceWidth

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: ReviewChipLayout.iconPointSize, weight: .semibold)
        let result = NSMutableAttributedString()
        for (index, chip) in chips.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: " ", attributes: gapAttributes))
            }
            if let image = UIImage(systemName: chip.systemName, withConfiguration: symbolConfig)?
                .withTintColor(chip.color.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal)
            {
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = CGRect(
                    x: 0, y: (font.capHeight - image.size.height) / 2,
                    width: image.size.width, height: image.size.height)
                let icon = NSMutableAttributedString(attachment: attachment)
                icon.addAttributes(textAttributes, range: NSRange(location: 0, length: icon.length))
                result.append(icon)
                // No-break space: the icon stays with its count
                result.append(NSAttributedString(string: "\u{00A0}", attributes: textAttributes))
            }
            result.append(NSAttributedString(string: chip.count.compactFormatted, attributes: textAttributes))
        }
        return result
    }
}

//
//  PaddingLabel.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 04.01.2026.
//

import UIKit

final class PaddingLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let base = super.intrinsicContentSize
        return CGSize(
            width: base.width + textInsets.left + textInsets.right,
            height: base.height + textInsets.top + textInsets.bottom
        )
    }
}

//
//  CardHugConstraints.swift
//  Purgio
//
//  Created by ZeynepMüslim on 09.11.2026.
//

import UIKit

/// Centered width/height constraints that make a card hug its asset's aspect ratio
/// (MonthReview on the iPhone Duo's inner display held sideways, see +Landscape).
struct CardHugConstraints {
    let width: NSLayoutConstraint
    let height: NSLayoutConstraint
    let all: [NSLayoutConstraint]

    init(card: UIView, in container: UIView) {
        width = card.widthAnchor.constraint(equalToConstant: 0)
        height = card.heightAnchor.constraint(equalToConstant: 0)
        all = [
            card.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            width,
            height
        ]
    }
}

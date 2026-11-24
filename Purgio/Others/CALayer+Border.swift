//
//  CALayer+Border.swift
//  Purgio
//
//  Created by Zeynep Müslim on 17.11.2026.
//

import UIKit

extension CALayer {
    /// Sets the border width, fading between the old and new width when `animated`
    /// (from wherever a running fade has got to, so quick changes don't jump)
    func setBorderWidth(_ width: CGFloat, animated: Bool, duration: TimeInterval = 0.25) {
        guard borderWidth != width else { return }
        if animated {
            let animation = CABasicAnimation(keyPath: "borderWidth")
            animation.fromValue = presentation()?.borderWidth ?? borderWidth
            animation.toValue = width
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            add(animation, forKey: "borderWidth")
        } else {
            removeAnimation(forKey: "borderWidth")
        }
        borderWidth = width
    }
}

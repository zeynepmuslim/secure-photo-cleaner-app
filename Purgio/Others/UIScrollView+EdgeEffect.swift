//
//  UIScrollView+EdgeEffect.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.11.2026.
//

import UIKit

extension UIScrollView {
    /// iOS 26: content scrolling under the navigation bar fades out progressively instead of
    /// under a solid band, as on the iPhone Duo's Settings panes. Earlier versions keep the
    /// bar's own background.
    func useSoftTopEdgeEffect() {
        if #available(iOS 26.0, *) {
            topEdgeEffect.style = .soft
        }
    }
}

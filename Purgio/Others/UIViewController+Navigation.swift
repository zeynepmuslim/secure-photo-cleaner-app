//
//  UIViewController+Navigation.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import UIKit

// MARK: - Replacing the top screen

extension UIViewController {
    /// Swaps this screen for another in its navigation stack, so Back skips the one that's done.
    func replaceInNavigationStack(with viewController: UIViewController, animated: Bool = true) {
        guard let navigationController else { return }
        var stack = navigationController.viewControllers
        if let index = stack.firstIndex(where: { $0 === self }) {
            stack.removeSubrange(index...)
        }
        stack.append(viewController)
        navigationController.setViewControllers(stack, animated: animated)
    }
}

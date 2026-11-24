//
//  MonthsListViewController+Hub.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import Photos
import UIKit

// MARK: - Opening a Month's Hub

extension MonthsListViewController {
    /// The one route to a month's hub from another screen. It opens the media type's tab (Photos 1,
    /// Videos 2) on its months list. While the list splits at the fold (the iPhone Duo inner
    /// display), the month becomes the selected row and the detail beside it. Otherwise its hub
    /// is pushed over the list, as Home's `navigateOnTab` does.
    static func openHub(
        in tabBarController: UITabBarController?,
        mediaType: PHAssetMediaType,
        title: String,
        key: String,
        yearSection: YearSection? = nil
    ) {
        let index = mediaType == .video ? 2 : 1
        guard let tabBarController,
              let destination = tabBarController.viewControllers?[index] as? UINavigationController,
              let list = destination.viewControllers.first as? MonthsListViewController else { return }

        // Setting the index doesn't run the tab bar's own reset of the bin
        if let binController = tabBarController as? FloatingBinButtonController {
            binController.setBinButtonPlacement(.standard)
            binController.setBinButtonSuppressed(false)
        }
        tabBarController.selectedIndex = index
        destination.popToRootViewController(animated: false)

        list.selectDetail(key: key)
        // Lays the list out at the current size, so it decides the split before choosing
        destination.view.layoutIfNeeded()
        if list.isShowingDetail(forKey: key) { return }

        let hub = MonthFilterCardsViewController(
            monthTitle: title, monthKey: key, mediaType: mediaType, yearSection: yearSection)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            destination.pushViewController(hub, animated: true)
        }
    }
}

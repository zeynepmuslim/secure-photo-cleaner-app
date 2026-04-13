//
//  MonthReviewViewController+Helpers.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 15.02.2026.
//

import Photos
import UIKit

private enum Strings {
    static let noResultsTitle = NSLocalizedString("monthHelpers.noResultsTitle", comment: "No results title")
    static let noResultsMessage = NSLocalizedString("monthHelpers.noResultsMessage", comment: "No results message with suggestion")
    static let clearFilter = NSLocalizedString("monthHelpers.clearFilter", comment: "Clear filter button")
    static let backToMonths = NSLocalizedString("monthHelpers.backToMonths", comment: "Back to months button")
    static let tryAnotherMonth = NSLocalizedString("monthHelpers.tryAnotherMonth", comment: "Try another month button")
    static let monthEmptyMessage = NSLocalizedString("monthHelpers.monthEmptyMessage", comment: "Month empty message")
    static let monthCompleteTitle = NSLocalizedString("monthHelpers.monthCompleteTitle", comment: "Month complete title")
    static let viewDeleteBin = NSLocalizedString("monthHelpers.viewDeleteBin", comment: "View delete bin button")
    static func noPhotosInMonth(monthTitle: String) -> String {
        String(format: NSLocalizedString("monthHelpers.noPhotosInMonth", comment: "No photos in month title, e.g. 'No Photos in January 2025'"), monthTitle)
    }
    static func monthCompleteMessage(count: Int, monthTitle: String) -> String {
        String(format: NSLocalizedString("monthHelpers.monthCompleteMessage", comment: "Month complete message, e.g. 'You reviewed all 42 photos in January 2025.'"), count, monthTitle)
    }
}

extension MonthReviewViewController {

    func showEmptyState() {
        let isFilterActive = preSortedAssets != nil || filterContext != .none
        let showTryAnother = isFilterActive && (navigationSource == .dashboard || navigationSource == .luckyPicker)

        if isFilterActive {
            markEmptyFilterFinished()
            if showTryAnother {
                emptyStateView.configure(
                    icon: "line.3.horizontal.decrease.circle",
                    iconColor: .systemGreen,
                    title: Strings.noResultsTitle,
                    message: Strings.noResultsMessage,
                    actionTitle: Strings.tryAnotherMonth,
                    onAction: { [weak self] in self?.tryAnotherMonth() }
                )
            } else {
                emptyStateView.configure(
                    icon: "line.3.horizontal.decrease.circle",
                    iconColor: .systemGreen,
                    title: Strings.noResultsTitle,
                    message: Strings.noResultsMessage,
                    actionTitle: Strings.clearFilter,
                    onAction: { [weak self] in
                        self?.navigationController?.popViewController(animated: true)
                    }
                )
            }
        } else {
            // Month is empty
            emptyStateView.configure(
                icon: "calendar",
                iconColor: .systemGray,
                title: Strings.noPhotosInMonth(monthTitle: monthTitle),
                message: Strings.monthEmptyMessage,
                actionTitle: Strings.backToMonths,
                onAction: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            )
        }

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        emptyStateView.show(animated: true)

        cleanupVideo()
        cardContainerView.alpha = 0
        videoController.playPauseButton.alpha = 0
        videoController.controlsContainer.alpha = 0
    }

    func tryAnotherMonth() {
        let service = PhotoLibraryService.shared

        if let buckets = service.getCachedMonthBuckets(mediaType: mediaType) {
            navigateToRandomMonth(from: buckets)
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            let buckets = await service.loadMonthBuckets(mediaType: self.mediaType)
            await MainActor.run { [weak self] in
                self?.navigateToRandomMonth(from: buckets)
            }
        }
    }

    private func navigateToRandomMonth(from buckets: [PhotoLibraryService.MonthBucket]) {
        let otherBuckets = buckets.filter { $0.key != monthKey }
        guard let picked = otherBuckets.randomElement() else { return }

        let newVC = MonthReviewViewController(
            monthTitle: picked.title,
            monthKey: picked.key,
            mediaType: mediaType,
            filterContext: filterContext
        )
        newVC.navigationSource = navigationSource

        guard let nav = navigationController else { return }
        var vcs = nav.viewControllers
        vcs.removeLast()
        vcs.append(newVC)
        nav.setViewControllers(vcs, animated: true)
    }

    func showInitialICloudWarning() {
        guard !settingsStore.hasShownInitialICloudWarning && !isShowingICloudWarning else { return }
        guard !settingsStore.allowInternetAccess else { return }
        guard checkForICloudOnlyAssets() else { return }

        settingsStore.hasShownInitialICloudWarning = true
        isShowingICloudWarning = true

        let sheet = iCloudWarningSheet(type: .initial)

        sheet.onEnableInternet = { [weak self] in
            self?.enableInternetAndReload(reloadPhotos: true)
        }

        sheet.onContinueOffline = { [weak self] in
            self?.isShowingICloudWarning = false
        }

        present(sheet, animated: true)
    }

    func showPerCardICloudWarning(for asset: PHAsset) {
        guard !settingsStore.hasShownPerCardICloudWarning && !isShowingICloudWarning else { return }
        guard !settingsStore.allowInternetAccess else { return }

        settingsStore.hasShownPerCardICloudWarning = true
        isShowingICloudWarning = true

        let mediaType: MediaType = asset.mediaType == .video ? .video : .photo
        let sheet = iCloudWarningSheet(type: .perCard(mediaType))

        sheet.onEnableInternet = { [weak self] in
            self?.enableInternetAndReload()
        }

        sheet.onSkipThisOne = { [weak self] in
            guard let self = self else { return }
            self.isShowingICloudWarning = false
            self.markCurrentAsKeptAndAdvance()
        }

        present(sheet, animated: true)
    }

    func showICloudBadgeTapSheet() {
        guard !isShowingICloudWarning else { return }
        guard !settingsStore.allowInternetAccess else { return }

        isShowingICloudWarning = true

        let currentAsset = currentIndex < reviewAssets.count ? reviewAssets[currentIndex].asset : nil
        let mediaType: MediaType = currentAsset?.mediaType == .video ? .video : .photo
        let sheet = iCloudWarningSheet(type: .perCard(mediaType))

        sheet.onEnableInternet = { [weak self] in
            self?.enableInternetAndReload()
        }

        sheet.onSkipThisOne = { [weak self] in
            guard let self = self else { return }
            self.isShowingICloudWarning = false
            self.markCurrentAsKeptAndAdvance()
        }

        present(sheet, animated: true)
    }

    // MARK: - iCloud Sheet Helpers

    private func enableInternetAndReload(reloadPhotos: Bool = false) {
        isShowingICloudWarning = false
        settingsStore.allowInternetAccess = true
        haptics.impact(intensity: .medium)
        showInternetEnabledConfirmation()
        if reloadPhotos {
            loadPhotos()
        } else {
            refreshStack()
        }
    }

    private func markCurrentAsKeptAndAdvance() {
        if currentIndex < reviewAssets.count {
            let asset = reviewAssets[currentIndex].asset
            KeptAssetsStore.shared.addAssetId(asset.localIdentifier)
            keptCount += 1
            statsStore.recordReview(for: mediaType)
            saveProgress()
        }
        currentIndex += 1
        advanceToFirstUnprocessedIndex()
        refreshStack()
    }

    func showInternetEnabledConfirmation() {
        let alert = UIAlertController(
            title: nil, message: "Internet access enabled. iCloud photos will download.", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            alert.dismiss(animated: true)
        }
    }

    func openSettingsTab() {
        guard let tabBarController = tabBarController else { return }
        tabBarController.selectedIndex = 3
        if let settingsNav = tabBarController.viewControllers?[3] as? UINavigationController {
            settingsNav.popToRootViewController(animated: false)
            if let settingsVC = settingsNav.topViewController as? SettingsViewController {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    settingsVC.scrollToInternetToggle()
                }
            }
        }
    }

    func markEmptyFilterFinished() {
        switch filterContext {
        case .screenshots:
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .screenshots)
        case .largeFiles:
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .largeFiles)
        case .eyesClosed:
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .eyesClosed)
        case .screenRecordings:
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .screenRecordings)
        case .slowMotion:
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .slowMotion)
        case .timeLapse:
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .timeLapse)
        case .none:
            break
        }
    }

    func markNonEmptyFilterNotFinished() {
        switch filterContext {
        case .screenshots:
            MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .screenshots)
        case .largeFiles:
            MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .largeFiles)
        case .eyesClosed:
            MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .eyesClosed)
        case .screenRecordings:
            MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .screenRecordings)
        case .slowMotion:
            MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .slowMotion)
        case .timeLapse:
            MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .timeLapse)
        case .none:
            break
        }
    }

    @objc func handleUndo() {
        guard let action = historyManager.undoLastAction() else { return }
        haptics.success()

        currentIndex = action.index

        let asset = reviewAssets[currentIndex].asset

        switch action.actionType {
        case .store:
            willBeStoredStore.removeAssetId(asset.localIdentifier)
            storedCount -= 1
        case .delete:
            deleteBinStore.removeAssetId(asset.localIdentifier)
            deletedCount -= 1
            statsStore.undoDeletion(for: mediaType, bytes: action.assetSize)
            sessionIncrementCount = max(0, sessionIncrementCount - 1)
            updateGlobalBinButtonIncrement()
        case .keep:
            KeptAssetsStore.shared.removeAssetId(asset.localIdentifier)
            keptCount -= 1
        }

        statsStore.undoReview(for: mediaType)
        saveProgress()
        refreshStack()
    }

    @objc func undoHistoryDidChange() {
        updateHistoryButton()
    }

    func updateHistoryButton() {
        let count = historyManager.undoCount

        undoButton.isEnabled = count > 0
        historyButton.isEnabled = count > 0
        historyBadge.isHidden = count == 0

        if count > 0 {
            undoButton.tintColor = .label
            historyButton.tintColor = .label
            historyBadge.alpha = 1.0

            let newText = "\(count)"
            historyBadge.text = newText

            let size = CGSize(width: 300, height: 20)
            let textSize = (newText as NSString).boundingRect(
                with: size,
                options: .usesLineFragmentOrigin,
                attributes: [.font: historyBadge.font!],
                context: nil
            ).size

            historyBadgeWidthConstraint.constant = max(20, textSize.width + 10)
        } else {
            historyBadge.text = "0"
            undoButton.tintColor = .systemGray
            historyButton.tintColor = .systemGray
            historyBadge.alpha = 0
        }
    }

    // MARK: - Bin Button Management
    func updateBinSpacerWidth(animated: Bool) {
        guard let binButton = findFloatingBinButton() else { return }
        let isVisible = !binButton.isHidden && binButton.alpha > 0.01
        let measuredWidth = max(binButton.bounds.width, binButton.intrinsicContentSize.width)
        guard let binSpacerWidthConstraint = binSpacerWidthConstraint else { return }
        binSpacerWidthConstraint.constant = isVisible ? measuredWidth : 0

        let animations = {
            self.bottomControlsStack.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                animations()
            }
        } else {
            animations()
        }
    }

    func findFloatingBinButton() -> FloatingBinButton? {
        guard let rootView = tabBarController?.view else { return nil }
        return findFloatingBinButtonRecursive(in: rootView)
    }

    private func findFloatingBinButtonRecursive(in view: UIView) -> FloatingBinButton? {
        if let button = view as? FloatingBinButton {
            return button
        }
        for subview in view.subviews {
            if let match = findFloatingBinButtonRecursive(in: subview) {
                return match
            }
        }
        return nil
    }

    func configureGlobalBinButton() {
        //        let actualBinCount = DeleteBinStore.shared.count
        binController?.configureBinButton(
            mode: .increment(sessionIncrementCount),
            monthKey: monthKey,
            monthTitle: monthTitle,
            tapHandler: { [weak self] in
                self?.handleBinTap()
            }
        )
        updateBinSpacerWidth(animated: true)
    }

    func updateGlobalBinButtonIncrement() {
        binController?.configureBinButton(
            mode: .increment(sessionIncrementCount),
            monthKey: monthKey,
            monthTitle: monthTitle,
            tapHandler: { [weak self] in
                self?.handleBinTap()
            }
        )
        updateBinSpacerWidth(animated: true)
    }

    @objc func handleBinTap() {
        let binViewController = DeleteBinViewController()
        binViewController.filterMonthKey = monthKey
        binViewController.filterMonthTitle = monthTitle
        navigationController?.pushViewController(binViewController, animated: true)
    }

    @objc func deleteBinCountDidChange() {
        let actualBinCount = DeleteBinStore.shared.count
        if actualBinCount == 0 {
            sessionIncrementCount = 0
        } else if sessionIncrementCount > actualBinCount {
            sessionIncrementCount = actualBinCount
        }

        guard navigationController?.topViewController === self else { return }

        configureGlobalBinButton()
        updateBinSpacerWidth(animated: true)
    }

    func refreshSessionIncrementCountFromMonthBin() {
        let binIds = DeleteBinStore.shared.loadAssetIds()
        guard !binIds.isEmpty else {
            sessionIncrementCount = 0
            configureGlobalBinButton()
            updateBinSpacerWidth(animated: false)
            return
        }

        if !reviewAssets.isEmpty {
            let binSet = Set(binIds)
            let count = reviewAssets.reduce(0) { $0 + (binSet.contains($1.localIdentifier) ? 1 : 0) }
            sessionIncrementCount = count
            configureGlobalBinButton()
            updateBinSpacerWidth(animated: false)
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            let count = await self.photoLibraryService.countBinAssets(
                withLocalIdentifiers: binIds,
                inMonthKey: self.monthKey
            )
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.sessionIncrementCount = count
                self.configureGlobalBinButton()
                self.updateBinSpacerWidth(animated: false)
            }
        }
    }

    func refreshHistoryBadgeFromManager() {
        updateHistoryButton()
        historyManager.removeActionsForDeletedAssets()
    }

    // MARK: - Progress & Stats
    func recalculateCountsFromStores() {
        guard !reviewAssets.isEmpty else {
            //            print("[FILTER-STATS] recalculateCountsFromStores: reviewAssets is EMPTY, skipping")
            return
        }
        var actualDeleted = 0
        var actualKept = 0
        var actualStored = 0
        for ra in reviewAssets {
            let id = ra.localIdentifier
            if DeleteBinStore.shared.hasAssetId(id) {
                actualDeleted += 1
            } else if KeptAssetsStore.shared.hasAssetId(id) {
                actualKept += 1
            } else if WillBeStoredStore.shared.hasAssetId(id) {
                actualStored += 1
            }
        }
        //        print("[FILTER-STATS] recalculateCountsFromStores: filter=\(filterContext), reviewAssets=\(reviewAssets.count), deleted=\(actualDeleted), kept=\(actualKept), stored=\(actualStored)")
        deletedCount = actualDeleted
        keptCount = actualKept
        storedCount = actualStored
    }

    func saveProgress() {
        let progressKey = makeProgressKey()
        let previousProgress = progressStore.getProgress(forMonthKey: progressKey, mediaType: mediaType)

//        print("[FILTER-STATS] saveProgress() called — filter=\(filterContext), progressKey=\(progressKey)")
//        print(
//            "[FILTER-STATS]   current counts: deleted=\(deletedCount), kept=\(keptCount), stored=\(storedCount), originalTotal=\(originalTotalCount), currentIndex=\(currentIndex)"
//        )
//        print(
//            "[FILTER-STATS]   previousProgress: deleted=\(previousProgress.deletedCount), kept=\(previousProgress.keptCount), stored=\(previousProgress.storedCount), reviewed=\(previousProgress.reviewedCount), originalTotal=\(previousProgress.originalTotalCount)"
//        )

        let filterUpdate = (
            monthKey: progressKey, mediaType: mediaType,
            currentIndex: currentIndex,
            reviewedCount: deletedCount + keptCount + storedCount,
            deletedCount: deletedCount,
            keptCount: keptCount,
            storedCount: storedCount,
            originalTotalCount: originalTotalCount
        )

        if currentIndex > 0 {
            ReminderDataCenter.shared.markReviewActivity(
                monthKey: monthKey,
                mediaType: mediaType,
                reviewedCount: deletedCount + keptCount + storedCount,
                totalCount: originalTotalCount
            )
        }

        if filterContext != .none {
            guard previousProgress.originalTotalCount == 0 || previousProgress.originalTotalCount == originalTotalCount
            else {
                print(
//                    "[FILTER-STATS]  originalTotalCount changed (\(previousProgress.originalTotalCount) → \(originalTotalCount)) — skipping delta sync"
                )
                progressStore.saveProgress(
                    forMonthKey: filterUpdate.monthKey, mediaType: filterUpdate.mediaType,
                    currentIndex: filterUpdate.currentIndex, reviewedCount: filterUpdate.reviewedCount,
                    deletedCount: filterUpdate.deletedCount, keptCount: filterUpdate.keptCount,
                    storedCount: filterUpdate.storedCount, originalTotalCount: filterUpdate.originalTotalCount
                )
                return
            }

            let deltaReviewed = (deletedCount + keptCount + storedCount) - previousProgress.reviewedCount
            let deltaDeleted = deletedCount - previousProgress.deletedCount
            let deltaKept = keptCount - previousProgress.keptCount
            let deltaStored = storedCount - previousProgress.storedCount

//            print("[FILTER-STATS]   DELTA SYNC: deltaReviewed=\(deltaReviewed), deltaDeleted=\(deltaDeleted), deltaKept=\(deltaKept), deltaStored=\(deltaStored)")

            if deltaReviewed != 0 || deltaDeleted != 0 || deltaKept != 0 || deltaStored != 0 {
                let mainProgress = progressStore.getProgress(forMonthKey: monthKey, mediaType: mediaType)
//                print("[FILTER-STATS]   mainProgress (monthKey=\(monthKey)): deleted=\(mainProgress.deletedCount), kept=\(mainProgress.keptCount), stored=\(mainProgress.storedCount), reviewed=\(mainProgress.reviewedCount), originalTotal=\(mainProgress.originalTotalCount)")

                let mainTotal: Int
                if mainProgress.originalTotalCount > 0 {
                    mainTotal = mainProgress.originalTotalCount
                } else {
                    mainTotal = originalTotalCount
//                    print("[FILTER-STATS]  mainProgress.originalTotalCount was 0, using filter's originalTotalCount=\(originalTotalCount) as fallback")
                }

                let newReviewed = max(0, mainProgress.reviewedCount + deltaReviewed)
                let newDeleted = max(0, mainProgress.deletedCount + deltaDeleted)
                let newKept = max(0, mainProgress.keptCount + deltaKept)
                let newStored = max(0, mainProgress.storedCount + deltaStored)

                let clampedReviewed = mainTotal > 0 ? min(newReviewed, mainTotal) : newReviewed
                let actionSum = newDeleted + newKept + newStored
                let scale: Double =
                    (actionSum > clampedReviewed && clampedReviewed > 0)
                    ? Double(clampedReviewed) / Double(actionSum)
                    : 1.0
                let clampedDeleted = scale < 1.0 ? Int(Double(newDeleted) * scale) : newDeleted
                let clampedKept = scale < 1.0 ? Int(Double(newKept) * scale) : newKept
                let clampedStored = scale < 1.0 ? Int(Double(newStored) * scale) : newStored

//                print("[FILTER-STATS]   WRITING to main key: reviewed=\(clampedReviewed), deleted=\(clampedDeleted), kept=\(clampedKept), stored=\(clampedStored), originalTotal=\(max(mainTotal, mainProgress.originalTotalCount)), scale=\(scale)")

                progressStore.batchSave([
                    filterUpdate,
                    (
                        monthKey: monthKey, mediaType: mediaType,
                        currentIndex: mainProgress.currentIndex,
                        reviewedCount: clampedReviewed,
                        deletedCount: clampedDeleted,
                        keptCount: clampedKept,
                        storedCount: clampedStored,
                        originalTotalCount: max(mainTotal, mainProgress.originalTotalCount)
                    )
                ])
            } else {
//                print("[FILTER-STATS]   ALL DELTAS ARE 0 — no propagation to main key!")
                progressStore.saveProgress(
                    forMonthKey: filterUpdate.monthKey, mediaType: filterUpdate.mediaType,
                    currentIndex: filterUpdate.currentIndex, reviewedCount: filterUpdate.reviewedCount,
                    deletedCount: filterUpdate.deletedCount, keptCount: filterUpdate.keptCount,
                    storedCount: filterUpdate.storedCount, originalTotalCount: filterUpdate.originalTotalCount
                )
            }
        } else {
//            print("[FILTER-STATS]   (no filter, skipping delta sync)")
            progressStore.saveProgress(
                forMonthKey: filterUpdate.monthKey, mediaType: filterUpdate.mediaType,
                currentIndex: filterUpdate.currentIndex, reviewedCount: filterUpdate.reviewedCount,
                deletedCount: filterUpdate.deletedCount, keptCount: filterUpdate.keptCount,
                storedCount: filterUpdate.storedCount, originalTotalCount: filterUpdate.originalTotalCount
            )
        }
    }

    func makeProgressKey() -> String {
        switch filterContext {
        case .none:
            return monthKey
        case .screenshots:
            return "\(monthKey)_screenshots"
        case .largeFiles:
            return "\(monthKey)_largeFiles"
        case .eyesClosed:
            return "\(monthKey)_eyesClosed"
        case .screenRecordings:
            return "\(monthKey)_screenRecordings"
        case .slowMotion:
            return "\(monthKey)_slowMotion"
        case .timeLapse:
            return "\(monthKey)_timeLapse"
        }
    }

    func updateStats() {
        let reviewed: Int
        let displayTotal: Int
        let displayDeleted: Int
        let displayKept: Int
        let displayStored: Int

        if filterContext != .none {
            let mainProgress = progressStore.getProgress(forMonthKey: monthKey, mediaType: mediaType)
            displayDeleted = mainProgress.deletedCount
            displayKept = mainProgress.keptCount
            displayStored = mainProgress.storedCount
            reviewed = displayDeleted + displayKept + displayStored
            displayTotal = mainProgress.originalTotalCount > 0 ? mainProgress.originalTotalCount : originalTotalCount
        } else {
            displayDeleted = deletedCount
            displayKept = keptCount
            displayStored = storedCount
            reviewed = displayDeleted + displayKept + displayStored
            displayTotal = originalTotalCount
        }

//        print("[FILTER-STATS] updateStats() — filter=\(filterContext), reviewed=\(reviewed)/\(displayTotal), deleted=\(displayDeleted), kept=\(displayKept), stored=\(displayStored)")
        let attributedText = NSMutableAttributedString()

        func createAttachment(systemName: String, color: UIColor) -> NSAttributedString {
            let attachment = NSTextAttachment()
            let config = UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            guard let image = UIImage(systemName: systemName, withConfiguration: config)?.withTintColor(color) else {
                return NSAttributedString()
            }
            attachment.image = image

            let ratio = image.size.width / image.size.height
            let height: CGFloat = 13.0
            let width = height * ratio
            attachment.bounds = CGRect(x: 0, y: -2.5, width: width, height: height)
            return NSAttributedString(attachment: attachment)
        }

        let textAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.secondaryLabel,
            .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        ]

        attributedText.append(createAttachment(systemName: "eye.fill", color: .label))
        attributedText.append(
            NSAttributedString(string: " \(reviewed)/\(displayTotal)  |  ", attributes: textAttributes))

        attributedText.append(createAttachment(systemName: "trash.fill", color: .systemRed))
        attributedText.append(NSAttributedString(string: " \(displayDeleted)  |  ", attributes: textAttributes))

        attributedText.append(createAttachment(systemName: "checkmark.circle.fill", color: .systemGreen))
        attributedText.append(NSAttributedString(string: " \(displayKept)  |  ", attributes: textAttributes))

        attributedText.append(createAttachment(systemName: "archivebox.fill", color: .systemYellow))
        attributedText.append(NSAttributedString(string: " \(displayStored)", attributes: textAttributes))

        statsLabel.attributedText = attributedText

        if let ring = navProgressRing, originalTotalCount > 0 {
            let filterReviewed = deletedCount + keptCount + storedCount
            let progress = CGFloat(filterReviewed) / CGFloat(originalTotalCount)
            ring.setProgress(min(1.0, max(0.0, progress)))
        }
    }

    func showCompletionSummary() {
//        print("[FILTER-STATS] showCompletionSummary() — filter=\(filterContext), deleted=\(deletedCount), kept=\(keptCount), stored=\(storedCount), originalTotal=\(originalTotalCount)")
        saveProgress()

        let progressKey = makeProgressKey()
        progressStore.markComplete(
            forMonthKey: progressKey,
            mediaType: mediaType,
            totalCount: originalTotalCount,
            deletedCount: deletedCount,
            keptCount: keptCount,
            storedCount: storedCount,
            originalTotalCount: originalTotalCount
        )
        markEmptyFilterFinished()
        ReminderDataCenter.shared.markReviewActivity(
            monthKey: monthKey,
            mediaType: mediaType,
            reviewedCount: originalTotalCount,
            totalCount: originalTotalCount
        )
        UIView.animate(withDuration: 0.3) {
            self.leftGradient.alpha = 0
            self.rightGradient.alpha = 0
            self.topGradient.alpha = 0
            self.cardContainerView.alpha = 0
        }
        let alert = UIAlertController(
            title: Strings.monthCompleteTitle,
            message: Strings.monthCompleteMessage(count: originalTotalCount, monthTitle: monthTitle),
            preferredStyle: .alert)
        alert.addAction(
            UIAlertAction(title: Strings.backToMonths, style: .default) { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            })
        alert.addAction(
            UIAlertAction(title: Strings.viewDeleteBin, style: .default) { [weak self] _ in
                guard let self = self, let nav = self.navigationController else { return }
                let binViewController = DeleteBinViewController()
                nav.pushViewController(binViewController, animated: true)
                // Remove MonthReviewVC from stack -> bin's back button go to month list/filter
                nav.viewControllers.removeAll { $0 === self }
            })
        present(alert, animated: true)
    }
}

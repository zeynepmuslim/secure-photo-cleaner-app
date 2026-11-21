//
//  SimilarPhotosViewController+EndStates.swift
//  Purgio
//
//  Created by ZeynepMüslim on 21.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let noneTitle = NSLocalizedString("similarPhotos.noneTitle", comment: "No similar photos found: every photo is one of a kind")
    static let noneMessageLibraryUncounted = NSLocalizedString("similarPhotos.noneMessageLibraryUncounted", comment: "No similar photos found in the whole library, count unknown")
    private static func comparedCount(_ count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarPhotos.comparedCount", comment: "How many photos a scan compared, e.g. '92 photos'"),
            count)
    }
    static func noneMessage(count: Int, month: String) -> String {
        String(
            format: NSLocalizedString("similarPhotos.noneMessage", comment: "No similar photos found: compared count ('92 photos'), month"),
            comparedCount(count), month)
    }
    static func noneMessageLibrary(count: Int) -> String {
        String(
            format: NSLocalizedString("similarPhotos.noneMessageLibrary", comment: "No similar photos found in the whole library: compared count ('92 photos')"),
            comparedCount(count))
    }
    static let scanAgain = NSLocalizedString("similarPhotos.scanAgain", comment: "Scan again button")
    static let tryAnotherMonth = NSLocalizedString("similarPhotos.tryAnotherMonth", comment: "Try another month button")
    static let undoAll = NSLocalizedString("similarPhotos.undoAll", comment: "Undo all button")
    static let allCheckedTitle = NSLocalizedString("similarPhotos.allCheckedTitle", comment: "Every similar set is confirmed")
    static func allCheckedMessage(sets: Int, month: String, size: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarPhotos.allCheckedMessage", comment: "Every set confirmed: set count, month, size waiting in the bin"),
            sets, month, size)
    }
    static func allCheckedMessageLibrary(sets: Int, size: String) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("similarPhotos.allCheckedMessageLibrary", comment: "Every set confirmed in a whole-library scan: set count, size waiting in the bin"),
            sets, size)
    }
}

// MARK: - Empty and finished states

extension SimilarPhotosViewController {

    private enum EndStateLayout {
        static let accessorySpacing: CGFloat = 12
    }

    /// The month's name inside a sentence ("August"); a year session keeps its title.
    private var shortMonthName: String? {
        guard let monthKey, let monthTitle else { return nil }
        return DateFormatterManager.shared.monthName(fromMonthKey: monthKey) ?? monthTitle
    }

    /// The month's other open filters, or nil when nothing is left (or there is no month).
    private func makeNextStepsView() -> MonthNextStepsView? {
        guard let monthKey, let shortMonthName else { return nil }
        let nextSteps = MonthNextStepsView()
        guard nextSteps.configure(
            monthTitle: shortMonthName, monthKey: monthKey, mediaType: mediaType, excluding: .similar)
        else { return nil }
        nextSteps.onSelect = { [weak self] filter in self?.openFilter(filter) }
        return nextSteps
    }

    /// Continue resumes the month's All Photos deck; a complete month has nothing to continue.
    private var continueTitle: String? {
        guard let monthKey else { return nil }
        return MonthFilterStatusStore.FilterType.continueTitle(monthKey: monthKey, mediaType: mediaType)
    }

    // MARK: Every set is checked

    /// Everything confirmed: the stamp, how much waits in the bin, this visit's split, the
    /// month's other open filters, Continue beside the bin, and "Undo all".
    func showAllCheckedState() {
        exitStoreModeOnAllCards(except: nil)

        var deleted = 0
        var kept = 0
        var stored = 0
        var bytes: Int64 = 0
        for index in confirmedThisVisit {
            guard let action = processedActions[index] else { continue }
            deleted += action.deletedAssets.count
            kept += action.keptAssets.count
            stored += action.storedAssets.count
            bytes += action.deletedAssets.reduce(Int64(0)) { $0 + byteSize(of: $1, inSetAt: index) }
        }

        let splitCard = ReviewSplitCardView()
        splitCard.configure(deleted: deleted, kept: kept, stored: stored)
        let accessory = UIStackView(arrangedSubviews: [splitCard])
        accessory.axis = .vertical
        accessory.spacing = EndStateLayout.accessorySpacing
        if let nextSteps = makeNextStepsView() {
            accessory.addArrangedSubview(nextSteps)
        }

        let size = bytes.formattedBytes()
        let message = shortMonthName.map {
            Strings.allCheckedMessage(sets: similarGroups.count, month: $0, size: size)
        } ?? Strings.allCheckedMessageLibrary(sets: similarGroups.count, size: size)

        endStateUsesBinSlot = true
        emptyStateView.trailingSlotWidth = GeneralConstants.BinSlot.compactWidth
        emptyStateView.configure(
            hero: .stamp,
            title: Strings.allCheckedTitle,
            message: message,
            accessory: accessory,
            actionTitle: continueTitle,
            actionIcon: "play.fill",
            onAction: { [weak self] in self?.openFilter(.allContent) },
            secondaryTitle: Strings.undoAll,
            onSecondary: { [weak self] in self?.undoAllFromFinishedState() })
        // The bin moves with the row when the fold changes the layout
        emptyStateView.onLayoutModeChange = { [weak self] in
            guard let self, self.endStateUsesBinSlot else { return }
            self.sendEndStateBinSlotIfNeeded()
            self.tabBarController?.view.layoutIfNeeded()
        }

        presentEndState()
    }

    /// Takes back every set confirmed on this visit and shows the list again.
    private func undoAllFromFinishedState() {
        revert(setsAt: confirmedThisVisit.sorted())
        HapticFeedbackManager.shared.impact(intensity: .medium)
        hideEmptyState()
        showList()
    }

    // MARK: None found

    /// Nothing similar: the stamp, how much was compared, the month's other open filters,
    /// Continue and "Scan again" (board "Empty & finished states · A + B").
    func showEmptyState() {
        hideSkeletonLoading()

        if let monthKey = monthKey {
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .similar)
        }

        let showTryAnother = navigationSource == .dashboard || navigationSource == .luckyPicker
        endStateUsesBinSlot = false
        emptyStateView.trailingSlotWidth = nil
        emptyStateView.onLayoutModeChange = nil
        emptyStateView.configure(
            hero: .stamp,
            title: Strings.noneTitle,
            message: emptyStateMessage(),
            accessory: makeNextStepsView(),
            actionTitle: continueTitle,
            actionIcon: "play.fill",
            onAction: { [weak self] in self?.openFilter(.allContent) },
            secondaryTitle: showTryAnother ? Strings.tryAnotherMonth : Strings.scanAgain,
            onSecondary: { [weak self] in
                if showTryAnother {
                    self?.tryAnotherMonth()
                } else {
                    self?.startScan()
                }
            })

        presentEndState()
    }

    private func presentEndState() {
        isShowingEmptyState = true
        listContentView.isHidden = true
        emptyStateView.isHidden = false
        emptyStateView.update(railEdge: DuoLayout.railEdge(tabBarController, in: view))
        emptyStateView.show(animated: true)
        lastSentBinSlot = nil
        applyEndStateBinButton()
    }

    func hideEmptyState() {
        guard isShowingEmptyState else { return }
        isShowingEmptyState = false
        endStateUsesBinSlot = false
        emptyStateView.hide(animated: false)
        emptyStateView.isHidden = true
        lastSentBinSlot = nil
        binController?.setBinButtonSuppressed(false)
    }

    // MARK: Bin

    /// "None found" has its bottom row where the bin would float; the finished state keeps the
    /// bin in the slot beside its primary. Every push and pop resets both, so this runs again
    /// in `viewDidAppear`.
    func applyEndStateBinButton() {
        guard isShowingEmptyState, navigationController?.topViewController === self else { return }
        binController?.setBinButtonSuppressed(!endStateUsesBinSlot)
        guard endStateUsesBinSlot else { return }
        binController?.configureBinButton(
            mode: .count(DeleteBinStore.shared.count),
            monthKey: monthKey,
            monthTitle: monthTitle,
            tapHandler: nil)
        binController?.showBinButton()
        sendEndStateBinSlotIfNeeded()
    }

    /// The slot is sent again only when it moves (the rail, folding, a size change).
    func sendEndStateBinSlotIfNeeded() {
        guard isShowingEmptyState, endStateUsesBinSlot, navigationController?.topViewController === self,
              let slot = emptyStateView.trailingSlotFrameInWindow, slot != lastSentBinSlot
        else { return }
        lastSentBinSlot = slot
        binController?.setBinButtonPlacement(.slot(slot))
    }

    // MARK: Routes

    /// "We compared 92 photos in August 2025…"; a whole-library scan counts the library's photos.
    private func emptyStateMessage() -> String {
        if let monthTitle {
            return Strings.noneMessage(count: assets?.count ?? 0, month: monthTitle)
        }
        if let count = assets?.count {
            return Strings.noneMessageLibrary(count: count)
        }
        if let buckets = photoLibraryService.getCachedMonthBuckets(mediaType: mediaType) {
            return Strings.noneMessageLibrary(count: buckets.reduce(0) { $0 + $1.totalCount })
        }
        return Strings.noneMessageLibraryUncounted
    }

    /// Opens another of the month's filters in place of this screen (FilterType+Route).
    private func openFilter(_ filter: MonthFilterStatusStore.FilterType) {
        guard let monthKey, let monthTitle else { return }
        let destination = filter.makeViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType,
            // A year session's screens share its preloaded assets
            yearAssets: monthKey.hasPrefix("year-") ? assets : nil,
            navigationSource: navigationSource)
        replaceInNavigationStack(with: destination)
    }

    private func tryAnotherMonth() {
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

        let newVC = SimilarPhotosViewController(
            assets: nil,
            monthTitle: picked.title,
            monthKey: picked.key,
            mediaType: mediaType
        )
        newVC.navigationSource = navigationSource

        replaceInNavigationStack(with: newVC)
    }
}

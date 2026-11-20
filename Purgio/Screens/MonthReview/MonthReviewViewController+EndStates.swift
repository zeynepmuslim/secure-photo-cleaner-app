//
//  MonthReviewViewController+EndStates.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.11.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let backToMonths = NSLocalizedString("monthHelpers.backToMonths", comment: "Back to months button")
    static let tryAnotherMonth = NSLocalizedString("monthHelpers.tryAnotherMonth", comment: "Try another month button")
    static let monthEmptyMessage = NSLocalizedString("monthHelpers.monthEmptyMessage", comment: "Month empty message")
    static func noPhotosInMonth(monthTitle: String) -> String {
        String(format: NSLocalizedString("monthHelpers.noPhotosInMonth", comment: "No photos in month title, e.g. 'No Photos in January 2025'"), monthTitle)
    }
    static func emptyFilterTitle(filter: String) -> String {
        String(format: NSLocalizedString("monthReview.emptyFilterTitle", comment: "A filter found nothing, e.g. 'No screenshots here'"), filter)
    }
    static func emptyFilterMessage(month: String, filter: String) -> String {
        String(format: NSLocalizedString("monthReview.emptyFilterMessage", comment: "A filter found nothing: month, then the filter's lowercase name"), month, filter)
    }
    static func backToMonth(_ month: String) -> String {
        String(format: NSLocalizedString("monthReview.backToMonth", comment: "Back to the month's hub, e.g. 'Back to August'"), month)
    }
    static func backToYear(_ year: String) -> String {
        String(format: NSLocalizedString("monthReview.backToYear", comment: "Back to the year's hub, e.g. 'Back to 2019'"), year)
    }
    static func completeTitle(_ month: String) -> String {
        String(format: NSLocalizedString("monthReview.completeTitle", comment: "A month is fully reviewed, e.g. 'August is done'"), month)
    }
    static func completeMessage(count: Int, isVideo: Bool) -> String {
        let format = isVideo
            ? NSLocalizedString("monthReview.completeMessageVideos", comment: "A month's videos are all reviewed")
            : NSLocalizedString("monthReview.completeMessagePhotos", comment: "A month's photos are all reviewed")
        return String.localizedStringWithFormat(format, count)
    }
    static func filterCompleteTitle(filter: String) -> String {
        String(format: NSLocalizedString("monthReview.filterCompleteTitle", comment: "A filter is fully reviewed: the filter's card title"), filter)
    }
    static func filterCompleteMessage(count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("monthReview.filterCompleteMessage", comment: "A filter's items are all reviewed"), count)
    }
}

// The deck's empty and finished states (board "Empty & finished states · A + B"), all shown by
// `EmptyStateView` over the deck:
// - a filter found nothing, or a filter deck is finished: the stamp, the month's other open
//   filters (`MonthNextStepsView`), "Continue · N left" and "Back to <month>";
// - the month has no photos: a calendar and "Back to months";
// - the month is finished: the stamp, the delete / keep / store split, the next unfinished
//   month beside the global bin, and "Back to months".
extension MonthReviewViewController {

    private enum EndStateLayout {
        /// The global bin's slot beside the primary button, as in the month hub
        static let binSlotWidth = GeneralConstants.BinSlot.compactWidth
    }

    private var isYearSession: Bool { monthKey.hasPrefix("year-") }

    /// "August" for a month, the title itself for a year session.
    private var shortSessionName: String {
        DateFormatterManager.shared.monthName(fromMonthKey: monthKey) ?? monthTitle
    }

    private var currentFilter: MonthFilterStatusStore.FilterType {
        MonthFilterStatusStore.FilterType(filterContext: filterContext)
    }

    // MARK: - Empty

    func showEmptyState() {
        guard !isShowingEndState else { return }

        if filterContext != .none {
            // The filter found nothing in this month: it's done
            markEmptyFilterFinished()
            let filterName = currentFilter.sentenceName(mediaType: mediaType)
            configureFilterEndState(
                title: Strings.emptyFilterTitle(filter: filterName),
                message: Strings.emptyFilterMessage(month: monthTitle, filter: filterName))
        } else {
            emptyStateView.trailingSlotWidth = nil
            emptyStateView.configure(
                hero: .symbol("calendar"),
                title: Strings.noPhotosInMonth(monthTitle: monthTitle),
                message: Strings.monthEmptyMessage,
                actionTitle: Strings.backToMonths,
                onAction: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                })
        }
        endStateUsesBinSlot = false
        presentEndState()
    }

    // MARK: - Finished

    func showCompletionSummary() {
        guard !isShowingEndState else { return }
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

        // A finished filter deck only finishes the month when its swipes covered the rest of it
        let isMonthComplete =
            filterContext == .none || progressStore.isComplete(monthKey: monthKey, mediaType: mediaType)
        if isMonthComplete {
            endStateUsesBinSlot = true
            emptyStateView.trailingSlotWidth = EndStateLayout.binSlotWidth
            configureMonthComplete(next: nil)
        } else {
            endStateUsesBinSlot = false
            configureFilterEndState(
                title: Strings.filterCompleteTitle(filter: currentFilter.cardTitle(mediaType: mediaType)),
                message: Strings.filterCompleteMessage(count: originalTotalCount))
        }
        presentEndState()
        if isMonthComplete {
            // The primary button becomes the next unfinished month once it's known
            loadNextUnfinishedSession()
        }
    }

    /// The stamp over the month's other open filters, Continue and the way back.
    private func configureFilterEndState(title: String, message: String) {
        emptyStateView.trailingSlotWidth = nil

        let nextSteps = MonthNextStepsView()
        let hasNextSteps = nextSteps.configure(
            monthTitle: shortSessionName, monthKey: monthKey, mediaType: mediaType, excluding: currentFilter)
        nextSteps.onSelect = { [weak self] filter in self?.openFilter(filter) }

        // Continue resumes the month's All Photos deck; a complete month has nothing to continue
        let continueTitle = MonthFilterStatusStore.FilterType.continueTitle(monthKey: monthKey, mediaType: mediaType)

        let showsTryAnother = navigationSource == .dashboard || navigationSource == .luckyPicker
        let secondaryTitle = showsTryAnother
            ? Strings.tryAnotherMonth
            : (isYearSession ? Strings.backToYear(shortSessionName) : Strings.backToMonth(shortSessionName))

        emptyStateView.configure(
            hero: .stamp,
            title: title,
            message: message,
            accessory: hasNextSteps ? nextSteps : nil,
            actionTitle: continueTitle,
            actionIcon: "play.fill",
            onAction: { [weak self] in self?.openFilter(.allContent) },
            secondaryTitle: secondaryTitle,
            onSecondary: { [weak self] in
                guard let self else { return }
                if showsTryAnother {
                    self.tryAnotherMonth()
                } else {
                    self.navigationController?.popViewController(animated: true)
                }
            })
    }

    /// The stamp over the month's split, the next unfinished month beside the bin's slot, and
    /// "Back to months". Without a next month the primary button is the way back.
    private func configureMonthComplete(next: (title: String, key: String)?) {
        let splitCard = ReviewSplitCardView()
        let main = progressStore.getProgress(forMonthKey: monthKey, mediaType: mediaType)
        // A filter deck that finished the month shows the month's numbers, not its own
        if filterContext == .none {
            splitCard.configure(deleted: deletedCount, kept: keptCount, stored: storedCount)
        } else {
            splitCard.configure(deleted: main.deletedCount, kept: main.keptCount, stored: main.storedCount)
        }
        let total = filterContext == .none ? originalTotalCount : main.originalTotalCount

        let backToMonths: () -> Void = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        emptyStateView.configure(
            hero: .stamp,
            title: Strings.completeTitle(shortSessionName),
            message: Strings.completeMessage(count: total, isVideo: mediaType == .video),
            accessory: splitCard,
            actionTitle: next?.title ?? Strings.backToMonths,
            actionIcon: next == nil ? nil : "play.fill",
            onAction: next.map { next in { [weak self] in self?.openNextSession(title: next.title, key: next.key) } }
                ?? backToMonths,
            secondaryTitle: next == nil ? nil : Strings.backToMonths,
            onSecondary: next == nil ? nil : backToMonths)
    }

    // MARK: - Showing

    private func presentEndState() {
        isShowingEndState = true

        if emptyStateView.superview == nil {
            emptyStateView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(emptyStateView)
            // Sides from the safe area; top and bottom from the view, so the bottom row can
            // rest on Home's rail baseline
            NSLayoutConstraint.activate([
                emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
                emptyStateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                emptyStateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
                emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        view.bringSubviewToFront(emptyStateView)
        emptyStateView.update(railEdge: DuoLayout.railEdge(tabBarController, in: view))

        cleanupVideo()
        setTableLayoutBarItemVisible(false)
        // The deck and everything that drives it step aside: the stats, the undo row, the
        // table layout's base and the sideways grips
        UIView.animate(withDuration: 0.3) {
            self.applyScreenBackground()
            [self.leftGradient, self.rightGradient, self.topGradient, self.cardContainerView,
             self.tableBaseContainerView, self.statsLabel, self.statsPill, self.bottomControlsStack,
             self.historyBadge, self.leftGrip, self.rightGrip, self.videoController.playPauseButton,
             self.videoController.controlsContainer].forEach { $0.alpha = 0 }
        } completion: { _ in
            // The glass buttons lens what's under them, so the badge must not be drawn at all
            self.historyBadge.isHidden = true
        }
        emptyStateView.show(animated: true)

        applyEndStateBinButton()
        view.setNeedsLayout()
    }

    /// Called on every layout pass.
    func updateEndStateLayout(railEdge: DuoLayout.RailEdge?) {
        guard isShowingEndState else { return }
        emptyStateView.update(railEdge: railEdge)
        sendEndStateBinSlotIfNeeded()
    }

    // MARK: - Bin

    /// A finished month keeps the bin in a slot beside its primary button; the other end
    /// states have their own bottom row where it would float, so it steps aside.
    func applyEndStateBinButton() {
        guard isShowingEndState, navigationController?.topViewController === self else { return }
        binController?.setBinButtonSuppressed(!endStateUsesBinSlot)
        configureEndStateBinButton()
    }

    func configureEndStateBinButton() {
        guard endStateUsesBinSlot else { return }
        // The unfiltered bin, in place of the finished deck, as "View Delete Bin" did
        binController?.configureBinButton(
            mode: .count(DeleteBinStore.shared.count),
            monthKey: nil,
            monthTitle: nil,
            tapHandler: { [weak self] in
                guard let self, let navigationController = self.navigationController else { return }
                navigationController.pushViewController(DeleteBinViewController(), animated: true)
                navigationController.viewControllers.removeAll { $0 === self }
            })
    }

    /// The slot is sent again only when it moves (the rail, folding, a size change).
    private func sendEndStateBinSlotIfNeeded() {
        guard endStateUsesBinSlot, navigationController?.topViewController === self,
              let slot = emptyStateView.trailingSlotFrameInWindow, slot != lastSentBinSlot else { return }
        lastSentBinSlot = slot
        binController?.setBinButtonPlacement(.slot(slot))
    }

    // MARK: - Routes

    /// Opens another of the month's filters in place of this deck, so Back skips the finished one.
    private func openFilter(_ filter: MonthFilterStatusStore.FilterType) {
        let destination = filter.makeViewController(
            monthTitle: monthTitle, monthKey: monthKey, mediaType: mediaType,
            // A year session's screens share its preloaded assets
            yearAssets: isYearSession ? preSortedAssets : nil,
            navigationSource: navigationSource)
        replaceInNavigationStack(with: destination)
    }

    /// Starts the next month's All Photos deck in place of this one. The finished month's hub,
    /// when it's right under this deck, goes too: Back from the new deck leads to the months.
    private func openNextSession(title: String, key: String) {
        guard let navigationController else { return }
        let deck = MonthReviewViewController(
            monthTitle: title, monthKey: key, mediaType: mediaType, filterContext: FilterContext.none)
        var stack = navigationController.viewControllers
        stack.removeAll { $0 === self }
        if let hub = stack.last as? MonthFilterCardsViewController, hub.sessionKey == monthKey {
            stack.removeLast()
        }
        stack.append(deck)
        navigationController.setViewControllers(stack, animated: true)
    }

    private func loadNextUnfinishedSession() {
        if let buckets = photoLibraryService.getCachedMonthBuckets(mediaType: mediaType) {
            applyNextUnfinishedSession(from: buckets)
            return
        }
        nextMonthTask?.cancel()
        nextMonthTask = Task { [weak self] in
            guard let self else { return }
            let buckets = await self.photoLibraryService.loadMonthBuckets(mediaType: self.mediaType)
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                self?.applyNextUnfinishedSession(from: buckets)
            }
        }
    }

    private func applyNextUnfinishedSession(from buckets: [PhotoLibraryService.MonthBucket]) {
        guard isShowingEndState, endStateUsesBinSlot,
              let next = nextUnfinishedSession(in: buckets) else { return }
        configureMonthComplete(next: next)
    }

    /// The next older session of this media type that isn't complete: a month, or a sparse
    /// year's `year-YYYY` session (the months list shows those as one row).
    private func nextUnfinishedSession(
        in buckets: [PhotoLibraryService.MonthBucket]
    ) -> (title: String, key: String)? {
        // Everything older than this session; "yyyy-MM" keys sort by date
        let floor = isYearSession ? "\(monthKey.dropFirst("year-".count))-00" : monthKey
        let yearTotals = Dictionary(grouping: buckets, by: { String($0.key.prefix(4)) })
            .mapValues { $0.reduce(0) { $0 + $1.totalCount } }

        for bucket in buckets.filter({ $0.key < floor }).sorted(by: { $0.key > $1.key }) {
            let year = String(bucket.key.prefix(4))
            let yearTotal = yearTotals[year] ?? bucket.totalCount
            let isSparseYear = yearTotal < GeneralConstants.BulkYear.sparseYearThreshold
            let key = isSparseYear ? "year-\(year)" : bucket.key
            let title = isSparseYear ? year : bucket.title
            let liveTotal = isSparseYear ? yearTotal : bucket.totalCount

            let progress = progressStore.getProgress(forMonthKey: key, mediaType: mediaType)
            let total = progress.originalTotalCount > 0 ? progress.originalTotalCount : liveTotal
            if total > 0, progress.reviewedCount < total {
                return (title, key)
            }
        }
        return nil
    }

    // MARK: - Another Month

    func tryAnotherMonth() {
        if let buckets = photoLibraryService.getCachedMonthBuckets(mediaType: mediaType) {
            navigateToRandomMonth(from: buckets)
            return
        }

        Task { [weak self] in
            guard let self = self else { return }
            let buckets = await self.photoLibraryService.loadMonthBuckets(mediaType: self.mediaType)
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
        replaceInNavigationStack(with: newVC)
    }
}

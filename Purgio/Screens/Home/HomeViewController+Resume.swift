//
//  HomeViewController+Resume.swift
//  Purgio
//
//  Created by ZeynepMüslim on 18.11.2026.
//

import Photos
import UIKit

// MARK: - Continue Where You Left Off

extension HomeViewController {

    private enum ResumeLayout {
        /// The dashboard keeps at least this much height below the rows (its regular minimum)
        static let dashboardMinimumHeight = HomeLayout.dashboardMinimumHeight
        /// The dashboard's roomy layout starts here; the single column gives up a row to reach
        /// it, as long as at least one row stays
        static let dashboardRoomyHeight = DashboardCard.roomyMinimumHeight
        /// Split at the fold the tiles give way to the rows down to their compact height
        static let tilesMinimumHeight: CGFloat = 60
    }

    // MARK: Data

    private struct SortableItem {
        let item: HomeResumeItem
        let year: Int
        let month: Int
    }

    /// Reads every in-progress month and sparse year off main, then shows them; with none in
    /// progress, the newest ones not started yet.
    func loadResumeItems() {
        guard photoLibraryService.authorizationStatus() != .notDetermined else { return }
        resumeLoadTask?.cancel()
        resumeLoadTask = Task { [weak self] in
            let items = await HomeViewController.makeResumeItems()
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.applyResumeItems(items)
            }
        }
    }

    private func applyResumeItems(_ items: [HomeResumeItem]) {
        guard items != resumeItems else { return }
        resumeItems = items
        resumeSection.configure(items: items)
        appliedResumeRowCount = nil
        view.setNeedsLayout()
    }

    /// Photo and video records that are started but not finished (the usual "complete" test),
    /// months and sparse years only, newest first. Runs off main: `ReviewProgressStore` is
    /// thread-safe and the buckets come from `PhotoLibraryService`'s async API.
    private nonisolated static func makeResumeItems() async -> [HomeResumeItem] {
        let allProgress = ReviewProgressStore.shared.getAllProgress()
        let photoBuckets = await PhotoLibraryService.shared.loadMonthBuckets(mediaType: .image)
        let videoBuckets = await PhotoLibraryService.shared.loadMonthBuckets(mediaType: .video)

        var sortable: [SortableItem] = []
        for (storeKey, progress) in allProgress {
            let mediaType: PHAssetMediaType
            let key: String
            if storeKey.hasPrefix("photo_") {
                mediaType = .image
                key = String(storeKey.dropFirst("photo_".count))
            } else if storeKey.hasPrefix("video_") {
                mediaType = .video
                key = String(storeKey.dropFirst("video_".count))
            } else {
                continue
            }
            let buckets = mediaType == .video ? videoBuckets : photoBuckets

            let item: HomeResumeItem
            let year: Int
            let month: Int
            if let (y, m) = monthParts(of: key) {
                let bucket = buckets.first { $0.key == key }
                let total = progress.originalTotalCount > 0 ? progress.originalTotalCount : (bucket?.totalCount ?? 0)
                item = HomeResumeItem(
                    key: key, mediaType: mediaType,
                    title: bucket?.title ?? DateFormatterManager.shared.displayMonth(fromMonthKey: key),
                    isYear: false,
                    deleted: progress.deletedCount, kept: progress.keptCount, stored: progress.storedCount,
                    total: total, reviewed: progress.reviewedCount, yearMonths: [])
                year = y
                month = m
            } else if let y = yearPart(of: key) {
                // The year's month buckets, as the months list builds its year section
                let yearMonths = buckets.filter { $0.key.hasPrefix("\(y)-") }.map {
                    MonthItem(
                        title: $0.title, key: $0.key, currentPhotoCount: $0.totalCount, reviewedCount: 0,
                        keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: $0.totalCount,
                        mediaType: mediaType)
                }
                let liveCount = yearMonths.reduce(0) { $0 + $1.currentPhotoCount }
                let total = progress.originalTotalCount > 0 ? progress.originalTotalCount : liveCount
                item = HomeResumeItem(
                    key: key, mediaType: mediaType, title: String(y), isYear: true,
                    deleted: progress.deletedCount, kept: progress.keptCount, stored: progress.storedCount,
                    total: total, reviewed: progress.reviewedCount, yearMonths: yearMonths)
                year = y
                // A year comes after that year's months
                month = 0
            } else {
                // Filter sub-keys ("<month>_<filter>") and anything else
                continue
            }

            let isComplete = item.total > 0 && item.reviewed >= item.total
            guard item.reviewed > 0, item.total > 0, !isComplete else { continue }
            sortable.append(SortableItem(item: item, year: year, month: month))
        }

        // Nothing in progress: the newest months not started yet, so the section stays put
        if sortable.isEmpty {
            let startedKeys = Set(allProgress.filter { $0.value.reviewedCount > 0 }.keys)
            sortable = notStartedItems(in: photoBuckets, mediaType: .image, startedKeys: startedKeys)
                + notStartedItems(in: videoBuckets, mediaType: .video, startedKeys: startedKeys)
        }

        return sortable.sorted { lhs, rhs in
            if lhs.year != rhs.year { return lhs.year > rhs.year }
            if lhs.month != rhs.month { return lhs.month > rhs.month }
            // Photos before videos for the same month
            return lhs.item.mediaType == .image && rhs.item.mediaType == .video
        }.prefix(HomeResumeSectionView.maximumRowCount).map(\.item)
    }

    /// Months (and sparse years, as the months list shows them) with nothing reviewed yet
    private nonisolated static func notStartedItems(
        in buckets: [PhotoLibraryService.MonthBucket], mediaType: PHAssetMediaType, startedKeys: Set<String>
    ) -> [SortableItem] {
        let prefix = mediaType == .video ? "video_" : "photo_"
        let isStarted: (String) -> Bool = { startedKeys.contains(prefix + $0) }

        var bucketsByYear: [Int: [PhotoLibraryService.MonthBucket]] = [:]
        for bucket in buckets where bucket.totalCount > 0 {
            guard let (year, _) = monthParts(of: bucket.key) else { continue }
            bucketsByYear[year, default: []].append(bucket)
        }

        var result: [SortableItem] = []
        for (year, yearBuckets) in bucketsByYear {
            let yearTotal = yearBuckets.reduce(0) { $0 + $1.totalCount }
            if yearTotal < GeneralConstants.BulkYear.sparseYearThreshold {
                let key = "year-\(year)"
                guard !isStarted(key) else { continue }
                let yearMonths = yearBuckets.map {
                    MonthItem(
                        title: $0.title, key: $0.key, currentPhotoCount: $0.totalCount, reviewedCount: 0,
                        keptCount: 0, deletedCount: 0, storedCount: 0, originalTotalCount: $0.totalCount,
                        mediaType: mediaType)
                }
                let item = HomeResumeItem(
                    key: key, mediaType: mediaType, title: String(year), isYear: true,
                    deleted: 0, kept: 0, stored: 0, total: yearTotal, reviewed: 0, yearMonths: yearMonths)
                result.append(SortableItem(item: item, year: year, month: 0))
            } else {
                for bucket in yearBuckets where !isStarted(bucket.key) {
                    guard let (_, month) = monthParts(of: bucket.key) else { continue }
                    let item = HomeResumeItem(
                        key: bucket.key, mediaType: mediaType, title: bucket.title, isYear: false,
                        deleted: 0, kept: 0, stored: 0, total: bucket.totalCount, reviewed: 0, yearMonths: [])
                    result.append(SortableItem(item: item, year: year, month: month))
                }
            }
        }
        return result
    }

    /// `yyyy-MM` → (year, month)
    private nonisolated static func monthParts(of key: String) -> (Int, Int)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2, parts[0].count == 4, parts[1].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), (1...12).contains(month)
        else { return nil }
        return (year, month)
    }

    /// `year-YYYY` → YYYY
    private nonisolated static func yearPart(of key: String) -> Int? {
        guard key.hasPrefix("year-") else { return nil }
        let digits = key.dropFirst("year-".count)
        guard digits.count == 4 else { return nil }
        return Int(digits)
    }

    // MARK: Fitting

    /// Shows as many rows as fit (at most 4) while the view that takes the
    /// free height keeps its minimum; hides the section when none fit or nothing is in progress.
    /// Runs after layout. The flexible view plus the section is the same height whatever the row
    /// count, so applying a count never changes the next pass's answer.
    func updateResumeRowCount() {
        let flexibleView: UIView
        let minimumHeight: CGFloat
        let cap = HomeResumeSectionView.maximumRowCount
        if foldSplitAxis == nil {
            flexibleView = dashboardCard
            minimumHeight = ResumeLayout.dashboardMinimumHeight
        } else {
            // Split at the fold the rows share the first side with the tiles
            flexibleView = quickAccessStack
            minimumHeight = ResumeLayout.tilesMinimumHeight
        }

        contentStack.layoutIfNeeded()
        let width = flexibleView.bounds.width
        guard width > 0 else { return }

        var budget = flexibleView.bounds.height
        if !resumeSection.isHidden {
            budget += resumeSection.bounds.height + HomeLayout.cardSpacing
        }

        let heights = resumeSection.rowHeights(fittingWidth: width)
        let header = resumeSection.headerHeight(fittingWidth: width)
        // What the flexible view keeps with each row count: [n] is with n rows
        var remaining: [CGFloat] = []
        var used = HomeLayout.cardSpacing + header
        for height in heights.prefix(cap) {
            used += height
            remaining.append(budget - used)
        }
        var count = remaining.filter { $0 >= minimumHeight }.count

        // Single column: prefer a roomy dashboard. A row that would push it below the roomy
        // height is left out, unless that leaves no rows (then the minimum rule stands).
        if foldSplitAxis == nil, count > 0, remaining[count - 1] < ResumeLayout.dashboardRoomyHeight,
            let roomyCount = remaining.prefix(count).lastIndex(where: { $0 >= ResumeLayout.dashboardRoomyHeight })
        {
            count = roomyCount + 1
        }

        guard count != appliedResumeRowCount else { return }
        appliedResumeRowCount = count
        // Applied on the next turn, outside this layout pass: a stack view doesn't redo its
        // layout for an arranged view shown or hidden while it's being laid out.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.appliedResumeRowCount == count else { return }
            self.resumeSection.setVisibleRowCount(count)
            self.resumeSection.isHidden = count == 0
            self.view.setNeedsLayout()
        }
    }

    // MARK: Navigation

    func handleResumeSelection(_ item: HomeResumeItem) {
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let yearSection = item.isYear ? YearSection(year: item.title, months: item.yearMonths) : nil
        let viewController = MonthFilterCardsViewController(
            monthTitle: item.title, monthKey: item.key, mediaType: item.mediaType, yearSection: yearSection)
        navigateOnTab(index: item.mediaType == .video ? 2 : 1, pushing: viewController)
    }
}

//
//  MonthsListViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

extension Notification.Name {
    static let filterByYear = Notification.Name("filterByYear")
}

private enum Strings {
    static let allowAccessMessage = NSLocalizedString("monthsList.allowAccessMessage", comment: "Message asking user to allow photo access")
    static let allowPhotoAccess = NSLocalizedString("monthsList.allowPhotoAccess", comment: "Allow photo access button")
    static let accessDenied = NSLocalizedString("monthsList.accessDenied", comment: "Photo access denied message")
    static let openSettings = NSLocalizedString("monthsList.openSettings", comment: "Open Settings button")
    static let status = NSLocalizedString("monthsList.status", comment: "Status section header")
    static let allYears = NSLocalizedString("monthsList.allYears", comment: "All years filter option")
    static let year = NSLocalizedString("monthsList.year", comment: "Year filter label")
    static let filter = NSLocalizedString("monthsList.filter", comment: "Filter button label")
    static let resetFilters = NSLocalizedString("monthsList.resetFilters", comment: "Reset filters button title")
    static let photos = NSLocalizedString("monthsList.photos", comment: "Photos tab/nav title")
    static let videos = NSLocalizedString("monthsList.videos", comment: "Videos tab/nav title")
    static let noPhotosYet = NSLocalizedString("monthsList.noPhotosYet", comment: "Empty state title for photos")
    static let noVideosYet = NSLocalizedString("monthsList.noVideosYet", comment: "Empty state title for videos")
    static let limitedAccessPhotos = NSLocalizedString("monthsList.limitedAccessPhotos", comment: "Limited access hint for photos")
    static let limitedAccessVideos = NSLocalizedString("monthsList.limitedAccessVideos", comment: "Limited access hint for videos")
    static let noContentPhotos = NSLocalizedString("monthsList.noContentPhotos", comment: "Empty library hint for photos")
    static let noContentVideos = NSLocalizedString("monthsList.noContentVideos", comment: "Empty library hint for videos")
    static let selectPhotos = NSLocalizedString("monthsList.selectPhotos", comment: "Select photos action title")
    static let selectVideos = NSLocalizedString("monthsList.selectVideos", comment: "Select videos action title")
    static let older = NSLocalizedString("monthsList.older", comment: "Section header for entries older than tracked years")
}

final class MonthsListViewController: UIViewController {

    private let tableView: UITableView = {
        let table = UITableView(frame: .zero, style: .insetGrouped)
        table.separatorInsetReference = .fromCellEdges
//        table.backgroundColor = .red
        table.backgroundColor = .mainBackground
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.useSoftTopEdgeEffect()
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let permissionStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let permissionLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.allowAccessMessage
        label.textColor = .textSecondary
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }()

    private let permissionButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(Strings.allowPhotoAccess, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        return button
    }()

    // Skeleton loading
    private var skeletonListView: SkeletonMonthListView?
    private var skeletonBottomConstraint: NSLayoutConstraint?

    // iOS 26+ top gradient blur view
    private var topGradientView: GradientView?

    // iPhone Duo inner display: the list on one side of the fold, the selected month's hub
    // (an embedded MonthFilterCardsViewController) on the other
    private let detailContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .mainBackground
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var detailViewController: MonthFilterCardsViewController?
    /// The month key (or `year-YYYY`) the detail shows; kept while the split is off, so it
    /// comes back on the same row.
    private var selectedDetailKey: String?
    /// Axis the screen is split along at the fold; nil means the single list.
    private var detailSplitAxis: NSLayoutConstraint.Axis?
    private var singleListConstraints: [NSLayoutConstraint] = []
    private var sidewaysSplitConstraints: [NSLayoutConstraint] = []
    private var uprightSplitConstraints: [NSLayoutConstraint] = []
    /// Sideways: the list's trailing edge (from the view's leading edge).
    private var listTrailingToFold: NSLayoutConstraint?
    /// Sideways: the detail's leading edge (from the view's leading edge).
    private var detailLeadingToFold: NSLayoutConstraint?
    /// Upright: the detail fills the raised half and ends at the gap (from the view's top).
    private var detailBottomToFold: NSLayoutConstraint?
    /// Upright: the list starts `listTopClearance` below the detail (from the view's top).
    private var listTopToFold: NSLayoutConstraint?
    /// Upright: the list's frame starts this far below the detail, so rows scrolling up are cut
    /// off before they reach its cards; the rest of the gap is the list's top inset
    private let listTopClearance = GeneralConstants.EdgePadding.small
    /// Upright: over the list's top edge, rows scrolling up blur away under it (as Settings' base)
    private let listTopBlurView: ProgressiveBlurView = {
        let view = ProgressiveBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    private var listTopBlurHeight: NSLayoutConstraint?
    private var isDetailSplitActive: Bool { detailSplitAxis != nil }

    // MARK: - Private Services

    private let photoLibraryService = PhotoLibraryService.shared
    private let progressStore = ReviewProgressStore.shared

    // MARK: - Private State

    // Data Source
    private var allMonths: [MonthItem] = []
    private var yearSections: [YearSection] = []

    // Filters
    private var activeYearFilter: String? = nil   // nil = All Years
    private var activeStatusFilter: FilterStatus = .all
    private var filterBarButton: UIBarButtonItem?

    // Access to global bin button controller
    private var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    // MARK: - Constants

    private let mediaType: PHAssetMediaType

    // MARK: - Computed Strings

    private var isVideo: Bool { mediaType == .video }
    private var mediaTitle: String { isVideo ? Strings.videos : Strings.photos }
    private var noItemsTitle: String { isVideo ? Strings.noVideosYet : Strings.noPhotosYet }
    private var limitedAccessMessage: String {
        isVideo ? Strings.limitedAccessVideos : Strings.limitedAccessPhotos
    }
    private var noContentMessage: String {
        isVideo ? Strings.noContentVideos : Strings.noContentPhotos
    }
    private var selectMediaTitle: String { isVideo ? Strings.selectVideos : Strings.selectPhotos }
    // MARK: - Init

    init(mediaType: PHAssetMediaType) {
        self.mediaType = mediaType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .mainBackground

        // Set navigation title
        title = mediaTitle
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        setupUI()
        setupConstraint()
        configureTopGradientView()
        setupFilterButton()
        updatePermissionState()
        setupNotifications()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Ensure gradient stays on top during tab switches
        if #available(iOS 26.0, *) {
            if let gradientView = topGradientView {
                view.bringSubviewToFront(gradientView)
            }
        }

        // Reload months to show updated progress
        loadMonths()

        // Configure global bin button to show if there are items in bin. With the detail
        // showing, its hub configures the bin for its month and moves it into its bottom row.
        if detailViewController == nil {
            configureGlobalBinButton()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDetailSplit()
        updateBinButtonInset()
    }

    // MARK: - Setup

    private func setupUI() {
        // Add targets
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(YearAggregateCell.self,
            forCellReuseIdentifier: YearAggregateCell.reuseIdentifier)
        permissionButton.addTarget(self, action: #selector(handlePermissionTap), for: .touchUpInside)

        // Build view hierarchy
        permissionStack.addArrangedSubview(permissionLabel)
        permissionStack.addArrangedSubview(permissionButton)

        view.addSubview(tableView)
        view.addSubview(listTopBlurView)
        view.addSubview(detailContainerView)
        view.addSubview(permissionStack)

        // Wide displays (iPhone Duo inner display in landscape) keep rows at a readable width
        tableView.cellLayoutMarginsFollowReadableWidth = true

        updateBinButtonInset()
    }

    /// Room for the floating bin button, which sits above a bottom tab bar. On iPhone Duo's
    /// vertical rail the button moves down to the bottom edge, so the last row ends on Home's
    /// baseline (view bottom − 20) like the button, without the safe area and last footer gap.
    /// The loading skeleton ends on the same line.
    private func updateBinButtonInset() {
        let isVerticalRail = DuoLayout.isVerticalRail(tabBarController)
        let skeletonBottom: CGFloat = isVerticalRail ? -DuoLayout.RailPadding.bottom : 0
        if skeletonBottomConstraint?.constant != skeletonBottom {
            skeletonBottomConstraint?.constant = skeletonBottom
        }

        var bottom: CGFloat = 100
        let lastSection = tableView.numberOfSections - 1
        let lastFooterHeight = lastSection >= 0 ? tableView.rectForFooter(inSection: lastSection).height : 0
        if isVerticalRail || detailSplitAxis == .horizontal {
            // Sideways split too: the last row ends on Home's baseline, level with the detail
            bottom = DuoLayout.RailPadding.bottom - lastFooterHeight - tableView.safeAreaInsets.bottom
        } else if detailSplitAxis == .vertical {
            // Upright the bin sits in the detail above: the last row ends 16pt above the tab bar
            bottom = GeneralConstants.EdgePadding.medium - lastFooterHeight
        }
        guard tableView.contentInset.bottom != bottom else { return }
        tableView.contentInset.bottom = bottom
        tableView.verticalScrollIndicatorInsets.bottom = max(bottom, 0)
    }

    private func setupConstraint() {
        // The table is a vertical scroller that insets its rows by the safe area, so it pins
        // to the view; the detail's hub pins its own content to its safe area
        let tableTop = tableView.topAnchor.constraint(equalTo: view.topAnchor)
        let tableTrailing = tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        let tableBottom = tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        singleListConstraints = [tableTop, tableTrailing, tableBottom]

        // Sideways (vertical fold): list | detail
        let listTrailing = tableView.trailingAnchor.constraint(equalTo: view.leadingAnchor)
        let detailLeading = detailContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        sidewaysSplitConstraints = [
            tableTop, listTrailing, tableBottom,
            detailLeading,
            detailContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            detailContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ]
        listTrailingToFold = listTrailing
        detailLeadingToFold = detailLeading

        // Upright (horizontal fold): the detail on the raised half, standing still, and the
        // list on the base, scrolling under the blur at its top
        let detailBottom = detailContainerView.bottomAnchor.constraint(equalTo: view.topAnchor)
        let listTop = tableView.topAnchor.constraint(equalTo: view.topAnchor)
        uprightSplitConstraints = [
            listTop, tableTrailing, tableBottom,
            detailContainerView.topAnchor.constraint(equalTo: view.topAnchor),
            detailContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            detailContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            detailBottom
        ]
        detailBottomToFold = detailBottom
        listTopToFold = listTop

        let blurHeight = listTopBlurView.heightAnchor.constraint(equalToConstant: 0)
        listTopBlurHeight = blurHeight

        NSLayoutConstraint.activate(singleListConstraints)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),

            listTopBlurView.topAnchor.constraint(equalTo: tableView.topAnchor),
            listTopBlurView.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
            listTopBlurView.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
            blurHeight,

            permissionStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            permissionStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            permissionStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            permissionStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFilterByYear(_:)),
            name: .filterByYear,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePhotoLibraryChange),
            name: .photoLibraryDidChange,
            object: nil
        )
    }

    @objc private func handlePhotoLibraryChange() {
        loadMonths()
    }

    @objc private func handleFilterByYear(_ notification: Notification) {
        guard let year = notification.userInfo?["year"] as? String else { return }
        activeYearFilter = year
        applyFilters()

        // Scroll to top to show the filtered content
        if !yearSections.isEmpty {
            tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: true)
        }
    }

    // MARK: - Bin Button

    private func configureGlobalBinButton() {
        let count = DeleteBinStore.shared.count
        binController?.configureBinButton(
            mode: .count(count),
            monthKey: nil,
            monthTitle: nil,
            tapHandler: { [weak self] in
                self?.handleBinTap()
            }
        )

        // Always show the bin button on Photos/Videos tabs
        binController?.showBinButton()
    }

    private func handleBinTap() {
        let binVC = DeleteBinViewController()
        navigationController?.pushViewController(binVC, animated: true)
    }

    // MARK: - Detail Split

    /// Splits the screen at the fold on the iPhone Duo inner display: sideways the list before
    /// the fold and the selected month's hub after it; upright the hub on the raised half,
    /// standing still, and the list on the base. Like Home, it splits wherever a fold crosses the
    /// view (inactive included, so nothing jumps when the device folds); a horizontal fold
    /// only in regular width, so the cover display keeps the single list.
    private func updateDetailSplit() {
        var fold = FoldRegion.splittingFold(in: view)
        if let candidate = fold, candidate.width >= candidate.height,
           traitCollection.horizontalSizeClass != .regular {
            fold = nil
        }
        let status = photoLibraryService.authorizationStatus()
        let hasRows = (status == .authorized || status == .limited) && !yearSections.isEmpty
        if !hasRows { fold = nil }

        let axis: NSLayoutConstraint.Axis? = fold.map { $0.height > $0.width ? .horizontal : .vertical }
        if axis != detailSplitAxis {
            applyDetailSplit(axis)
        }

        guard let fold = fold, let axis = axis else { return }
        let foldStart = axis == .horizontal ? fold.minX : fold.minY
        let foldLength = axis == .horizontal ? fold.width : fold.height
        let foldCenter = foldStart + foldLength / 2
        // Fully open, the panes keep the fold gap, centered on the fold line.
        // Folded, they clear the whole region.
        let isFolded = FoldRegion.activeFold(in: view) != nil
        let gap = isFolded
            ? max(GeneralConstants.Spacer.foldGap, foldLength)
            : GeneralConstants.Spacer.foldGap
        let firstEdge = foldCenter - gap / 2
        if axis == .horizontal {
            // The fold's x is physical; measured from the leading edge it holds for
            // left-to-right languages, the only ones the app ships (English, Turkish)
            setConstant(firstEdge, of: listTrailingToFold)
            setConstant(foldCenter + gap / 2, of: detailLeadingToFold)
        } else {
            // The detail ends at the gap; the list starts a clearance below it, its top inset
            // keeping the first row a gap away, and the blur fills the gap. Fully open the gap
            // is small, so the blur keeps a minimum band over the first header's own padding.
            setConstant(firstEdge, of: detailBottomToFold)
            setConstant(firstEdge + listTopClearance, of: listTopToFold)
            setConstant(max(gap - listTopClearance, GeneralConstants.EdgePadding.content), of: listTopBlurHeight)
            setListTopInset(max(0, gap - listTopClearance))
            updateListTopBlur()
        }
    }

    private func setConstant(_ constant: CGFloat, of constraint: NSLayoutConstraint?) {
        guard let constraint = constraint, constraint.constant != constant else { return }
        constraint.constant = constant
    }

    private func setListTopInset(_ top: CGFloat) {
        guard tableView.contentInset.top != top else { return }
        // A list resting at its top keeps resting there when the top inset changes
        let wasAtTop = tableView.contentOffset.y <= -tableView.adjustedContentInset.top + 0.5
        tableView.contentInset.top = top
        tableView.verticalScrollIndicatorInsets.top = top
        if wasAtTop {
            tableView.contentOffset.y = -tableView.adjustedContentInset.top
        }
    }

    /// Upright: the blur over the list's top shows only as far as rows have scrolled under it
    private func updateListTopBlur() {
        guard detailSplitAxis == .vertical else { return }
        listTopBlurView.setContentOverlap(tableView.contentOffset.y + tableView.adjustedContentInset.top)
    }

    private func applyDetailSplit(_ axis: NSLayoutConstraint.Axis?) {
        detailSplitAxis = axis
        NSLayoutConstraint.deactivate(singleListConstraints + sidewaysSplitConstraints + uprightSplitConstraints)
        switch axis {
        case .horizontal?: NSLayoutConstraint.activate(sidewaysSplitConstraints)
        case .vertical?: NSLayoutConstraint.activate(uprightSplitConstraints)
        case nil: NSLayoutConstraint.activate(singleListConstraints)
        @unknown default: NSLayoutConstraint.activate(singleListConstraints)
        }
        detailContainerView.isHidden = axis == nil
        listTopBlurView.isHidden = axis != .vertical
        if axis != .vertical {
            setListTopInset(0)
        }

        if axis == nil {
            removeDetail()
            tableView.indexPathsForSelectedRows?.forEach { tableView.deselectRow(at: $0, animated: false) }
            // The hub's disappearance put the bin back in its standard place. Only while the
            // list is on top: mid push or pop, the bin belongs to the other screen.
            if navigationController?.topViewController === self {
                configureGlobalBinButton()
            }
        } else {
            ensureDetailSelection()
        }
    }

    /// Keeps the selected row if it's still listed, else picks the first unfinished one
    /// (the first row when every one is done), and shows it in the detail.
    private func ensureDetailSelection() {
        guard isDetailSplitActive else { return }
        let indexPath = selectedDetailKey.flatMap { indexPath(forDetailKey: $0) } ?? firstUnfinishedIndexPath()
        guard let indexPath = indexPath else {
            removeDetail()
            return
        }
        if tableView.indexPathForSelectedRow != indexPath {
            tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
        }
        showDetail(at: indexPath)
    }

    private func showDetail(at indexPath: IndexPath) {
        let key = detailKey(at: indexPath)
        selectedDetailKey = key
        guard detailViewController?.sessionKey != key else { return }

        let ys = yearSections[indexPath.section]
        let detail: MonthFilterCardsViewController
        if isSparseYear(ys) {
            detail = MonthFilterCardsViewController(
                monthTitle: ys.year, monthKey: key, mediaType: mediaType, yearSection: ys, isEmbedded: true)
        } else {
            detail = MonthFilterCardsViewController(
                monthTitle: ys.months[indexPath.row].title, monthKey: key, mediaType: mediaType, isEmbedded: true)
        }

        // The old hub leaves the bin in its slot, where the new hub's slot is too, so the bin
        // doesn't jump to its standard place and back. A snapshot of it fades out over the new one.
        let snapshot = detailViewController?.view.snapshotView(afterScreenUpdates: false)
        detailViewController?.keepsBinPlacementOnDisappear = true
        removeDetail()
        addChild(detail)
        detail.view.translatesAutoresizingMaskIntoConstraints = false
        detailContainerView.addSubview(detail.view)
        NSLayoutConstraint.activate([
            detail.view.topAnchor.constraint(equalTo: detailContainerView.topAnchor),
            detail.view.leadingAnchor.constraint(equalTo: detailContainerView.leadingAnchor),
            detail.view.trailingAnchor.constraint(equalTo: detailContainerView.trailingAnchor),
            detail.view.bottomAnchor.constraint(equalTo: detailContainerView.bottomAnchor)
        ])
        detail.didMove(toParent: self)
        detailViewController = detail

        guard let snapshot = snapshot else { return }
        snapshot.frame = detailContainerView.bounds
        detailContainerView.addSubview(snapshot)
        UIView.animate(withDuration: 0.25, animations: {
            snapshot.alpha = 0
        }, completion: { _ in
            snapshot.removeFromSuperview()
        })
    }

    private func removeDetail() {
        guard let detail = detailViewController else { return }
        detail.willMove(toParent: nil)
        detail.view.removeFromSuperview()
        detail.removeFromParent()
        detailViewController = nil
    }

    private func isSparseYear(_ ys: YearSection) -> Bool {
        ys.totalItemCount < GeneralConstants.BulkYear.sparseYearThreshold
    }

    private func detailKey(at indexPath: IndexPath) -> String {
        let ys = yearSections[indexPath.section]
        return isSparseYear(ys) ? "year-\(ys.year)" : ys.months[indexPath.row].key
    }

    private func indexPath(forDetailKey key: String) -> IndexPath? {
        for (section, ys) in yearSections.enumerated() {
            if isSparseYear(ys) {
                if "year-\(ys.year)" == key { return IndexPath(row: 0, section: section) }
            } else if let row = ys.months.firstIndex(where: { $0.key == key }) {
                return IndexPath(row: row, section: section)
            }
        }
        return nil
    }

    /// The topmost row that isn't complete, the same test as everywhere; the first row when
    /// every one is done.
    private func firstUnfinishedIndexPath() -> IndexPath? {
        for (section, ys) in yearSections.enumerated() {
            if isSparseYear(ys) {
                let item = makeYearItem(for: ys)
                let total = item.originalTotalCount > 0 ? item.originalTotalCount : item.currentTotalCount
                if !(total > 0 && item.reviewedCount >= total) { return IndexPath(row: 0, section: section) }
            } else if let row = ys.months.firstIndex(where: { month in
                let total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
                return !(total > 0 && month.reviewedCount >= total)
            }) {
                return IndexPath(row: row, section: section)
            }
        }
        return yearSections.isEmpty ? nil : IndexPath(row: 0, section: 0)
    }

    // MARK: - Top Gradient

    private func configureTopGradientView() {
        // Only add gradient view on iOS 26+
        if #available(iOS 26.0, *) {
            let gradientView = GradientView()
            gradientView.translatesAutoresizingMaskIntoConstraints = false
            gradientView.isUserInteractionEnabled = false
            gradientView.colors = [
                .mainBackground,
                .mainBackground.withAlphaComponent(0)
            ]
            gradientView.locations = [0.0, 1.0]
            gradientView.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientView.endPoint = CGPoint(x: 0.5, y: 1.0)
            view.addSubview(gradientView)

            self.topGradientView = gradientView

            // Layout constraints - spans from top of view to bottom of navigation bar (includes Dynamic Island)
            NSLayoutConstraint.activate([
                gradientView.topAnchor.constraint(equalTo: view.topAnchor),
                gradientView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                gradientView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                gradientView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
            ])
        }
    }

    // MARK: - Empty State

    private func updateEmptyState() {
        if yearSections.isEmpty {
            let isLimited = photoLibraryService.authorizationStatus() == .limited
            let emptyStateView = EmptyStateView()
            emptyStateView.configure(
                icon: "photo.on.rectangle.angled",
                iconColor: .systemGray,
                title: noItemsTitle,
                message: isLimited ? limitedAccessMessage : noContentMessage,
                actionTitle: isLimited ? selectMediaTitle : nil,
                onAction: isLimited
                    ? { [weak self] in
                        self?.presentLimitedLibraryPicker()
                    } : nil
            )
            tableView.backgroundView = emptyStateView
            emptyStateView.show(animated: true)
        } else {
            tableView.backgroundView = nil
        }
    }

    private func presentLimitedLibraryPicker() {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: self) { [weak self] _ in
            DispatchQueue.main.async {
                self?.photoLibraryService.invalidateMonthBucketsCache()
                self?.loadMonths()
            }
        }
    }

    // MARK: - Permission

    private func updatePermissionState() {
        let status = photoLibraryService.authorizationStatus()
        switch status {
        case .authorized, .limited:
            permissionStack.isHidden = true
            tableView.isHidden = false
            loadMonths()
        case .notDetermined:
            permissionLabel.text = Strings.allowAccessMessage
            permissionButton.setTitle(Strings.allowPhotoAccess, for: .normal)
            permissionStack.isHidden = false
            tableView.isHidden = true
        default:
            permissionLabel.text = Strings.accessDenied
            permissionButton.setTitle(Strings.openSettings, for: .normal)
            permissionStack.isHidden = false
            tableView.isHidden = true
        }
    }

    // MARK: - Data Loading

    private func loadMonths() {
        let status = photoLibraryService.authorizationStatus()
        guard status == .authorized || status == .limited else { return }
        showSkeletonLoading()
        Task {
            let buckets = await photoLibraryService.loadMonthBuckets(mediaType: mediaType)
            let allMonths = buckets.map { bucket -> MonthItem in
                // Load progress for this month with media type
                let progress = self.progressStore.getProgress(forMonthKey: bucket.key, mediaType: self.mediaType)

                // Sync originalTotalCount if live count has diverged from stored value
                var syncedTotal = progress.originalTotalCount
                if progress.originalTotalCount > 0 && bucket.totalCount != progress.originalTotalCount {
                    let newTotal = bucket.totalCount
                    let oldTotal = progress.originalTotalCount
                    ReviewProgressStore.shared.saveProgress(
                        forMonthKey: bucket.key,
                        mediaType: self.mediaType,
                        currentIndex: progress.currentIndex,
                        reviewedCount: progress.reviewedCount,
                        deletedCount: progress.deletedCount,
                        keptCount: progress.keptCount,
                        storedCount: progress.storedCount,
                        originalTotalCount: newTotal
                    )
                    if newTotal > oldTotal {
                        MonthFilterStatusStore.shared.clearAllFinishedFilters(monthKey: bucket.key)
                    }
                    syncedTotal = newTotal
                }

                return MonthItem(
                    title: bucket.title,
                    key: bucket.key,
                    currentPhotoCount: bucket.totalCount,
                    reviewedCount: progress.reviewedCount,
                    keptCount: progress.keptCount,
                    deletedCount: progress.deletedCount,
                    storedCount: progress.storedCount,
                    originalTotalCount: syncedTotal,
                    mediaType: self.mediaType
                )
            }

            self.allMonths = allMonths
            self.applyFilters()
            self.hideSkeletonLoading()
        }
    }

    // MARK: - Skeleton Loading

    private func showSkeletonLoading() {
        // Only show skeleton if we don't have data yet
        guard yearSections.isEmpty else { return }

        tableView.isHidden = true

        if skeletonListView == nil {
            let skeleton = SkeletonMonthListView(rowCount: 8)
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(skeleton)

            // Same width as the inset-grouped rows, which follow the readable width
            // and the side safe areas (vertical rail, Split View). Its bottom follows
            // the table's last row (see updateBinButtonInset), so rows past it are clipped.
            skeleton.clipsToBounds = true
            let bottom = skeleton.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            NSLayoutConstraint.activate([
                skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                skeleton.leadingAnchor.constraint(equalTo: tableView.readableContentGuide.leadingAnchor),
                skeleton.trailingAnchor.constraint(equalTo: tableView.readableContentGuide.trailingAnchor),
                bottom
            ])

            self.skeletonListView = skeleton
            skeletonBottomConstraint = bottom
            updateBinButtonInset()
            skeleton.startAnimating()
        }
        skeletonListView?.isHidden = false
    }

    private func hideSkeletonLoading() {
        tableView.isHidden = false
        skeletonListView?.fadeOut()
        skeletonListView = nil
        skeletonBottomConstraint = nil
    }

    // MARK: - Filters

    private var hasActiveFilter: Bool {
        activeYearFilter != nil || activeStatusFilter != .all
    }

    private func updateResetButton() {
        if hasActiveFilter {
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
            let image = UIImage(systemName: "arrow.counterclockwise", withConfiguration: config)
            let resetButton = UIBarButtonItem(
                image: image,
                style: .plain,
                target: self,
                action: #selector(handleResetFiltersTap)
            )
            resetButton.title = Strings.resetFilters
            resetButton.tintColor = .textPrimary
            navigationItem.leftBarButtonItem = resetButton
        } else {
            navigationItem.leftBarButtonItem = nil
        }
    }

    @objc private func handleResetFiltersTap() {
        activeYearFilter = nil
        activeStatusFilter = .all
        applyFilters()
    }

    private func applyFilters() {
        // 1. Filter
        let filteredMonths = allMonths.filter { month in
            // Year Filter
            if let yearFilter = activeYearFilter {
                let year = month.key.components(separatedBy: "-").first ?? ""
                if year != yearFilter {
                    return false
                }
            }

            // Status Filter
            switch activeStatusFilter {
            case .all:
                return true
            case .completed:
                let total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
                return total > 0 && month.reviewedCount >= total
            case .inProgress:
                let total = month.originalTotalCount > 0 ? month.originalTotalCount : month.currentPhotoCount
                return month.reviewedCount > 0 && month.reviewedCount < total
            case .notStarted:
                return month.reviewedCount == 0
            }
        }

        if hasActiveFilter && !allMonths.isEmpty && filteredMonths.isEmpty {
            activeYearFilter = nil
            activeStatusFilter = .all
            applyFilters()
            return
        }

        // 2. Group by Year
        var sections: [YearSection] = []
        var currentYear: String?
        var currentMonths: [MonthItem] = []

        for month in filteredMonths {
            let yearString = month.key.components(separatedBy: "-").first ?? ""
            let sectionYear = yearString.count == 4 ? yearString : Strings.older

            if sectionYear != currentYear {
                if let y = currentYear {
                    sections.append(YearSection(year: y, months: currentMonths))
                }
                currentYear = sectionYear
                currentMonths = []
            }
            currentMonths.append(month)
        }
        if let y = currentYear {
            sections.append(YearSection(year: y, months: currentMonths))
        }

        self.yearSections = sections

        // 3. Reload
        setupFilterButton()   // Update menu selection state and available years
        updateResetButton()   // Show/hide reset button based on active filters
        tableView.reloadData()
        updateBinButtonInset()   // Depends on the last section's footer
        updateEmptyState()
        view.setNeedsLayout()    // The split needs rows; it's decided on the next layout pass
        if isDetailSplitActive {
            ensureDetailSelection()
        }
    }

    private func setupFilterButton() {
        // Collect available years from local months + cache (so menu is ready before loadMonths completes)
        let localYears = Set(allMonths.compactMap { $0.key.components(separatedBy: "-").first })
        let cachedYears = Set(photoLibraryService.getCachedYears(mediaType: mediaType))
        let years = localYears.union(cachedYears).sorted(by: >)

        // Status Actions
        let statusActions = FilterStatus.allCases.map { status in
            UIAction(title: status.rawValue, state: activeStatusFilter == status ? .on : .off) { [weak self] _ in
                self?.activeStatusFilter = status
                self?.applyFilters()
            }
        }
        let statusMenu = UIMenu(title: Strings.status, options: .displayInline, children: statusActions)

        // Year Actions
        var yearActions: [UIAction] = []

        // "All Years" option
        let allYearsAction = UIAction(title: Strings.allYears, state: activeYearFilter == nil ? .on : .off) {
            [weak self] _ in
            self?.activeYearFilter = nil
            self?.applyFilters()
        }
        yearActions.append(allYearsAction)

        // Specific years
        for year in years {
            let action = UIAction(title: year, state: activeYearFilter == year ? .on : .off) { [weak self] _ in
                self?.activeYearFilter = year
                self?.applyFilters()
            }
            yearActions.append(action)
        }

        let yearMenu = UIMenu(title: Strings.year, options: .displayInline, children: yearActions)

        // Main Menu
        let menu = UIMenu(title: Strings.filter, children: [statusMenu, yearMenu])

        if let existing = filterBarButton {
            existing.menu = menu
        } else {
            let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            let image = UIImage(systemName: "line.3.horizontal.decrease.circle", withConfiguration: config)
            let barButton = UIBarButtonItem(title: Strings.filter, image: image, primaryAction: nil, menu: menu)
            barButton.tintColor = .textPrimary
            filterBarButton = barButton
            let helpItem = UIBarButtonItem.helpItem(target: self, action: #selector(handleHelpTap))
            if #available(iOS 27.1, *) {
                // Filter is the screen's frequent action; it overflows last on iPhone Duo
                barButton.visibilityPriority = .high
            }
            if #available(iOS 16.0, *) {
                navigationItem.trailingItemGroups = [
                    UIBarButtonItemGroup(barButtonItems: [helpItem, barButton], representativeItem: nil)
                ]
            } else {
                navigationItem.rightBarButtonItems = [barButton, helpItem]
            }
        }
    }

    // MARK: - Actions

    @objc private func handleHelpTap() {
        let onboardingVC = OnboardingViewController()

        // Configure as native bottom sheet
        if let sheet = onboardingVC.sheetPresentationController {
            if #available(iOS 16.0, *) {
                let threeQuarterDetent = UISheetPresentationController.Detent.custom { context in
                    return context.maximumDetentValue * 0.75
                }
                sheet.detents = [threeQuarterDetent]
            } else {
                sheet.detents = [.large()]   // Fallback for older iOS
            }
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
            // Don't set preferredCornerRadius - let system use device corners automatically
        }

        // Haptic feedback
        HapticFeedbackManager.shared.impact(intensity: .medium)

        present(onboardingVC, animated: true)
    }

    @objc private func handlePermissionTap() {
        let status = photoLibraryService.authorizationStatus()
        if status == .notDetermined {
            Task {
                _ = await photoLibraryService.requestAuthorization()
                updatePermissionState()
            }
        } else {
            guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension MonthsListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return yearSections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let ys = yearSections[section]
        return ys.totalItemCount < GeneralConstants.BulkYear.sparseYearThreshold
            ? 1
            : ys.months.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return yearSections[section].year
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.font = ThemeManager.Fonts.titleFont(size: 22, weight: .bold)
            header.textLabel?.textColor = .textPrimary
            header.textLabel?.text = header.textLabel?.text
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let ys = yearSections[indexPath.section]
        if ys.totalItemCount < GeneralConstants.BulkYear.sparseYearThreshold {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: YearAggregateCell.reuseIdentifier,
                for: indexPath) as! YearAggregateCell
            cell.configure(with: makeYearItem(for: ys))
            return cell
        }

        let reuseIdentifier = "MonthCell"
        let cell =
            tableView.dequeueReusableCell(withIdentifier: reuseIdentifier) as? MonthListCell
            ?? MonthListCell(style: .default, reuseIdentifier: reuseIdentifier)
        cell.configure(with: ys.months[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isDetailSplitActive {
            // The row stays selected and its hub shows beside the list
            if detailKey(at: indexPath) != selectedDetailKey {
                HapticFeedbackManager.shared.selection()
            }
            showDetail(at: indexPath)
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        let ys = yearSections[indexPath.section]
        if ys.totalItemCount < GeneralConstants.BulkYear.sparseYearThreshold {
            let vc = MonthFilterCardsViewController(
                monthTitle: ys.year,
                monthKey: "year-\(ys.year)",
                mediaType: mediaType,
                yearSection: ys)
            navigationController?.pushViewController(vc, animated: true)
            return
        }
        let item = ys.months[indexPath.row]
        let viewController = MonthFilterCardsViewController(
            monthTitle: item.title, monthKey: item.key, mediaType: mediaType)
        navigationController?.pushViewController(viewController, animated: true)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateListTopBlur()
    }
}

// MARK: - Year Aggregate Helpers

extension MonthsListViewController {
    private func makeYearItem(for yearSection: YearSection) -> YearItem {
        let key = "year-\(yearSection.year)"
        let p = ReviewProgressStore.shared.getProgress(forMonthKey: key, mediaType: mediaType)
        return YearItem(
            year: yearSection.year,
            key: key,
            months: yearSection.months,
            currentTotalCount: yearSection.totalItemCount,
            reviewedCount: p.reviewedCount,
            deletedCount: p.deletedCount,
            keptCount: p.keptCount,
            storedCount: p.storedCount,
            originalTotalCount: p.originalTotalCount,
            mediaType: mediaType
        )
    }
}

@available(iOS 17.0, *)
#Preview("Photos") {
    UINavigationController(rootViewController: MonthsListViewController(mediaType: .image))
}

@available(iOS 17.0, *)
#Preview("Videos") {
    UINavigationController(rootViewController: MonthsListViewController(mediaType: .video))
}

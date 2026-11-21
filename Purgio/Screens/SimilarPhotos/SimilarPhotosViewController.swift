//
//  SimilarPhotosViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import UIKit

// MARK: - Strings

private enum Strings {
    static let scanningMessage = NSLocalizedString("similarPhotos.scanningMessage", comment: "Scanning for similar photos progress message")
    static let similarPhotosTitle = NSLocalizedString("similarPhotos.title", comment: "Similar photos screen title")
    static let photosAccessDenied = NSLocalizedString("similarPhotos.photosAccessDenied", comment: "Photos access denied message")
    static func similarPhotosNavTitle(month: String) -> String {
        String(format: NSLocalizedString("similarPhotos.navTitle", comment: "Similar photos nav title with month"), month)
    }
}

/// The similar sets of a month, a year session or the whole library (board "Similar photos · A,
/// refined list, every size"): a self-sizing list of `SimilarSetCardView`s over a bottom row
/// with "Confirm all" and the bin's slot. The Duo's inner display splits it at the fold
/// (`+Fold.swift`); everything confirmed ends in the finished state (`+EndStates.swift`).
class SimilarPhotosViewController: UIViewController {

    struct UndoAction {
        let groupIndex: Int
        let deletedAssets: [PHAsset]
        let keptAssets: [PHAsset]
        let storedAssets: [PHAsset]
    }

    enum Section: Hashable {
        case summary
        case sets
    }

    enum Item: Hashable {
        case summary
        /// A set, by its signature
        case set(String)
    }

    /// How the list is arranged around the Duo's fold
    enum SplitLayout {
        /// One column: phones, the cover display, Split View
        case single
        /// Inner display held sideways: two columns, one on each side of the fold
        case sideways
        /// Inner display upright: a spotlight set on the raised half, the list on the base
        case upright
    }

    /// What the list's layout is built from; the layout is invalidated when it changes
    struct ListMetrics: Equatable {
        var layout: SplitLayout = .single
        var firstColumnWidth: CGFloat = 0
        var secondColumnWidth: CGFloat = 0
        var columnGap: CGFloat = 0
        var spacing: CGFloat = Layout.cardSpacing
    }

    enum Layout {
        static let cardSpacing: CGFloat = 10
        /// Short columns: iPhone SE, the Duo's cover display
        static let compactCardSpacing: CGFloat = 8
        static let shortColumnHeight: CGFloat = 700
        static let listToBottomRow: CGFloat = 12
        /// How far above the bottom row the list's blur reaches
        static let blurBandHeight: CGFloat = 28
        static let listTopInset: CGFloat = 8
        static let estimatedCardHeight: CGFloat = 250
        static let estimatedSummaryHeight: CGFloat = 24
        static let springDuration: TimeInterval = 0.4
        static let springDamping: CGFloat = 0.75
        static let springVelocity: CGFloat = 0.8
        static let spotlightDissolve: TimeInterval = 0.25
        /// Vertical scroll that ends a set's store mode
        static let storeModeScrollLimit: CGFloat = 30
    }

    // MARK: - Views

    /// Everything of the list: hidden while scanning and under the empty and finished states
    let listContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    lazy var collectionView: UICollectionView = {
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeListLayout())
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.register(SimilarSetCell.self, forCellWithReuseIdentifier: SimilarSetCell.reuseIdentifier)
        collectionView.register(
            SimilarSummaryCell.self, forCellWithReuseIdentifier: SimilarSummaryCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.useSoftTopEdgeEffect()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    var dataSource: UICollectionViewDiffableDataSource<Section, Item>?

    /// Cards scrolling under the bottom row blur progressively into the background
    let listBottomBlurView: ProgressiveBlurView = {
        let view = ProgressiveBlurView()
        view.edge = .bottom
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Rests on Home's baseline; the row inside starts at the fold while held sideways
    let bottomRowContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let bottomRowStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Layout.cardSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    lazy var confirmAllButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.addTarget(self, action: #selector(confirmAllTapped), for: .touchUpInside)
        return button
    }()

    /// Where the global bin sits (`setBinButtonPlacement(.slot)`)
    let binSlotView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Upright inner display: the summary card and the spotlight set, above the fold
    let raisedContainer: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let summaryCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = GeneralConstants.CornerRadius.card
        view.layer.cornerCurve = .continuous
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let raisedSummaryView: SimilarSummaryView = {
        let view = SimilarSummaryView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    let spotlightCardView: SimilarSetCardView = {
        let view = SimilarSetCardView()
        view.fillsHeight = true
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.hidesWhenStopped = true
        return indicator
    }()

    private var skeletonListView: SkeletonListView?
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = Strings.scanningMessage
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.isHidden = true
        return label
    }()

    let emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()
    var isShowingEmptyState = false
    /// The finished state keeps the bin in a slot beside its primary; "none found" hides it
    var endStateUsesBinSlot = false

    // MARK: - Layout state

    var collectionEdges: DuoEdgeConstraints?
    var bottomRowEdges: DuoEdgeConstraints?
    var singleConstraints: [NSLayoutConstraint] = []
    var sidewaysConstraints: [NSLayoutConstraint] = []
    var uprightConstraints: [NSLayoutConstraint] = []
    /// Sideways: where the bottom row starts
    var bottomRowStartConstraint: NSLayoutConstraint?
    /// Upright: where the raised half ends and the base's list starts
    var raisedBottomConstraint: NSLayoutConstraint?
    var baseTopConstraint: NSLayoutConstraint?
    var bottomRowHeightConstraint: NSLayoutConstraint?
    var binSlotWidthConstraint: NSLayoutConstraint?

    var splitLayout: SplitLayout = .single
    var hasAppliedSplitLayout = false
    var isFoldActive = false
    var listMetrics = ListMetrics()
    var isShortColumn = false
    var lastSentBinSlot: CGRect?
    var binSlotCount = 0
    /// The set the upright spotlight shows
    var spotlightIndex: Int?

    // MARK: - Data

    let photoLibraryService = PhotoLibraryService.shared

    var similarGroups: [SimilarAssetGroup] = []
    /// Each set's signature (its sorted asset ids), by index; the list's item ids
    var signatures: [String] = []
    var indexBySignature: [String: Int] = [:]
    var assets: [PHAsset]?
    let monthTitle: String?
    let monthKey: String?
    let mediaType: PHAssetMediaType

    var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    var processedGroupIndexes = Set<Int>()
    var processedActions: [Int: UndoAction] = [:]
    /// Each photo's mark, by set index and asset id: the one record the cards are drawn from
    var setStates: [Int: [String: SimilarPhotoState]] = [:]
    /// Each photo's bytes, by set signature and asset id; filled once after the scan, off main
    var sizesBySignature: [String: [String: Int64]] = [:]
    /// The sets confirmed since this screen opened: the finished state's totals and "Undo all"
    var confirmedThisVisit = Set<Int>()

    private var sizeTask: Task<Void, Never>?
    private var scrollStartOffset: CGFloat = 0

    var unconfirmedIndices: [Int] {
        similarGroups.indices.filter { !processedGroupIndexes.contains($0) }
    }

    private var compactMonthString: String? {
        guard let key = monthKey else { return nil }
        return DateFormatterManager.shared.compactMonth(fromMonthKey: key)
    }

    var navigationSource: NavigationSource = .manual

    // MARK: - Init

    init(
        assets: [PHAsset]? = nil, monthTitle: String? = nil, monthKey: String? = nil,
        mediaType: PHAssetMediaType = .image
    ) {
        self.assets = assets
        self.monthTitle = monthTitle
        self.monthKey = monthKey
        self.mediaType = mediaType
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupConstraint()
        setupDataSource()
        setupNavigationBar()

        if let compactMonth = compactMonthString {
            title = Strings.similarPhotosNavTitle(month: compactMonth)
        } else {
            title = Strings.similarPhotosTitle
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(handleBinCountChange), name: .deleteBinCountDidChange, object: nil)

        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) {
                (self: SimilarPhotosViewController, _: UITraitCollection) in
                self.applyAppearanceColors()
            }
        }

        applyConfirmAllButton()
        showSkeletonLoading()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // iOS 17+ uses registerForTraitChanges
        if #available(iOS 17.0, *) { return }
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyAppearanceColors()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let railEdge = DuoLayout.railEdge(tabBarController, in: view)
        collectionEdges?.update(railEdge: railEdge)
        bottomRowEdges?.update(railEdge: railEdge)
        emptyStateView.update(railEdge: railEdge)

        updateShortColumn()
        updateFoldSplit()
        updateListInsets()
        updateBinSlot()
        sendEndStateBinSlotIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Every push and pop resets the bin's placement and lets it show again
        lastSentBinSlot = nil
        if isShowingEmptyState {
            applyEndStateBinButton()
            return
        }

        if !similarGroups.isEmpty {
            configureGlobalBinButton()
            updateBinSlot()
            if sizesBySignature.isEmpty { loadSizes() }
            return
        }

        if assets != nil {
            runScan()
        } else if monthKey != nil {
            fetchAssetsForScan()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        exitStoreModeOnAllCards(except: nil)
        sizeTask?.cancel()
        sizeTask = nil
        if lastSentBinSlot != nil {
            lastSentBinSlot = nil
            binController?.setBinButtonPlacement(.standard)
        }
        if isMovingFromParent {
            binController?.hideBinButton()
        }
    }

    // MARK: - Setup

    private func setupNavigationBar() {
        navigationItem.rightBarButtonItem = .helpItem(target: self, action: #selector(handleHelpTap))
    }

    private func setupUI() {
        view.backgroundColor = .mainBackground

        view.addSubview(listContentView)
        listContentView.addSubview(collectionView)
        listContentView.addSubview(raisedContainer)
        raisedContainer.addSubview(summaryCardView)
        summaryCardView.addSubview(raisedSummaryView)
        raisedContainer.addSubview(spotlightCardView)
        listContentView.addSubview(listBottomBlurView)
        listContentView.addSubview(bottomRowContainer)
        bottomRowContainer.addSubview(bottomRowStack)
        bottomRowStack.addArrangedSubview(confirmAllButton)
        bottomRowStack.addArrangedSubview(binSlotView)

        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
        view.addSubview(emptyStateView)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            listContentView.topAnchor.constraint(equalTo: view.topAnchor),
            listContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Sides from the safe area; top and bottom from the view, so its bottom row can
            // rest on Home's rail baseline
            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 2 * GeneralConstants.EdgePadding.content),
            statusLabel.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -2 * GeneralConstants.EdgePadding.content)
        ])

        setupListConstraint()
    }

    @objc private func handleHelpTap() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        let helpSheet = SimilarPhotosHelpSheet()
        present(helpSheet, animated: true)
    }

    @objc private func handleBinCountChange() {
        guard !similarGroups.isEmpty, !isShowingEmptyState else { return }
        binSlotCount = DeleteBinStore.shared.count
        updateBinSlotWidth()
    }

    // MARK: - Data Loading

    private func fetchAssetsForScan() {
        guard let monthKey = monthKey else { return }

        let binnedIds = Set(DeleteBinStore.shared.loadAssetIds())
        let keptIds = Set(KeptAssetsStore.shared.loadAssetIds())
        let storedIds = Set(WillBeStoredStore.shared.loadAssetIds())
        let undoableIds = SimilarUndoStore.shared.getAllInvolvedAssetIds()

        Task {
            let fetchedAssets = await photoLibraryService.fetchPhotos(forMonthKey: monthKey, mediaType: mediaType)

            self.assets = fetchedAssets.filter { asset in
                if undoableIds.contains(asset.localIdentifier) {
                    return true
                }
                return !binnedIds.contains(asset.localIdentifier) && !keptIds.contains(asset.localIdentifier)
                    && !storedIds.contains(asset.localIdentifier)
            }

            self.statusLabel.text = Strings.scanningMessage
            self.runScan()
        }
    }

    func getSignature(for group: SimilarAssetGroup) -> String {
        return group.assets.map { $0.localIdentifier }.sorted().joined(separator: "|")
    }

    private func showSkeletonLoading() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        listContentView.isHidden = true

        if skeletonListView == nil {
            let skeleton = SkeletonListView(rowCount: 5)
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(skeleton)
            self.skeletonListView = skeleton

            // Its sides follow the list's: the safe area and the rail
            NSLayoutConstraint.activate([
                skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                skeleton.leadingAnchor.constraint(equalTo: collectionView.leadingAnchor),
                skeleton.trailingAnchor.constraint(equalTo: collectionView.trailingAnchor),
                skeleton.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        skeletonListView?.isHidden = false
        skeletonListView?.startAnimating()
    }

    func hideSkeletonLoading() {
        skeletonListView?.stopAnimating()
        skeletonListView?.isHidden = true
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
    }

    func startScan() {
        hideEmptyState()
        showSkeletonLoading()

        let status = PHPhotoLibrary.authorizationStatus()
        if status == .authorized || status == .limited {
            runScan()
        } else if status == .notDetermined {
            PHPhotoLibrary.requestAuthorization { [weak self] newStatus in
                if newStatus == .authorized || newStatus == .limited {
                    DispatchQueue.main.async {
                        self?.runScan()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.showPermissionError()
                    }
                }
            }
        } else {
            showPermissionError()
        }
    }

    private func runScan() {
        PhotoSimilarityService.shared.findSimilarPhotos(assets: assets) { [weak self] groups in
            guard let self = self else { return }
            self.hideSkeletonLoading()
            self.activityIndicator.stopAnimating()
            self.statusLabel.isHidden = true

            guard !groups.isEmpty else {
                self.showEmptyState()
                return
            }

            if let monthKey = self.monthKey {
                MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .similar)
            }
            self.similarGroups = groups
            self.signatures = groups.map { self.getSignature(for: $0) }
            self.indexBySignature = Dictionary(
                self.signatures.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

            // The best photo stays, the rest go to the bin, until the user says otherwise
            self.setStates.removeAll()
            for (index, group) in groups.enumerated() {
                var states: [String: SimilarPhotoState] = [:]
                for asset in group.assets {
                    states[asset.localIdentifier] =
                        asset.localIdentifier == group.bestAsset?.localIdentifier ? .keep : .delete
                }
                self.setStates[index] = states
            }

            self.processedGroupIndexes.removeAll()
            self.processedActions.removeAll()
            self.confirmedThisVisit.removeAll()
            self.sizesBySignature.removeAll()

            // Sets confirmed on an earlier visit come back confirmed, with what was chosen then
            for (index, group) in groups.enumerated() {
                guard let persisted = SimilarUndoStore.shared.getAction(forGroupSignature: self.signatures[index])
                else { continue }

                let deletedAssets = group.assets.filter { persisted.deletedIds.contains($0.localIdentifier) }
                let keptAssets = group.assets.filter { persisted.keptIds.contains($0.localIdentifier) }
                let storedAssets = group.assets.filter { persisted.storedIds.contains($0.localIdentifier) }

                self.processedActions[index] = UndoAction(
                    groupIndex: index,
                    deletedAssets: deletedAssets,
                    keptAssets: keptAssets,
                    storedAssets: storedAssets)
                self.processedGroupIndexes.insert(index)

                var states = self.setStates[index] ?? [:]
                deletedAssets.forEach { states[$0.localIdentifier] = .delete }
                keptAssets.forEach { states[$0.localIdentifier] = .keep }
                storedAssets.forEach { states[$0.localIdentifier] = .store }
                self.setStates[index] = states
            }

            self.showList()
            self.loadSizes()

            if let monthKey = self.monthKey {
                let similarKey = "\(monthKey)_similar"
                let totalSimilarPhotos = groups.reduce(0) { $0 + $1.assets.count }

                let current = ReviewProgressStore.shared.getProgress(
                    forMonthKey: similarKey, mediaType: self.mediaType)
                ReviewProgressStore.shared.saveProgress(
                    forMonthKey: similarKey,
                    mediaType: self.mediaType,
                    currentIndex: current.currentIndex,
                    reviewedCount: current.reviewedCount,
                    deletedCount: current.deletedCount,
                    keptCount: current.keptCount,
                    storedCount: current.storedCount,
                    originalTotalCount: totalSimilarPhotos
                )
            }
        }
    }

    /// Shows the list for the current sets, from the top.
    func showList() {
        listContentView.isHidden = false
        spotlightIndex = nil
        applySnapshot(reloading: true)
        updateSpotlight(animated: false)
        refreshSummary()
        configureGlobalBinButton()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        lastSentBinSlot = nil
        updateBinSlot()
    }

    /// Reads every photo's size once, off main, then fills in the subtitles and the summary.
    func loadSizes() {
        sizeTask?.cancel()
        let groups = similarGroups
        let signatures = signatures
        guard !groups.isEmpty else { return }

        sizeTask = Task { [weak self] in
            let sizes: [String: [String: Int64]] = await withCheckedContinuation { continuation in
                DispatchQueue.global(qos: .userInitiated).async {
                    var result: [String: [String: Int64]] = [:]
                    for (index, group) in groups.enumerated() {
                        var groupSizes: [String: Int64] = [:]
                        for asset in group.assets {
                            groupSizes[asset.localIdentifier] = asset.resourceMetadata().fileSize
                        }
                        result[signatures[index]] = groupSizes
                    }
                    continuation.resume(returning: result)
                }
            }
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, signatures == self.signatures else { return }
                self.sizesBySignature = sizes
                self.refreshVisibleCardSizes()
                self.refreshSummary()
            }
        }
    }

    /// One photo's bytes: the cached size, or read now when the sizes aren't in yet.
    func byteSize(of asset: PHAsset, inSetAt index: Int) -> Int64 {
        if index < signatures.count, let size = sizesBySignature[signatures[index]]?[asset.localIdentifier] {
            return size
        }
        return asset.resourceMetadata().fileSize
    }

    private func showPermissionError() {
        hideSkeletonLoading()
        activityIndicator.stopAnimating()
        statusLabel.text = Strings.photosAccessDenied
        statusLabel.isHidden = false
    }
}


// MARK: - UICollectionViewDelegate

extension SimilarPhotosViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollStartOffset = scrollView.contentOffset.y
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let delta = abs(scrollView.contentOffset.y - scrollStartOffset)
        if delta > Layout.storeModeScrollLimit {
            exitStoreModeOnAllCards(except: nil)
        }
        updateBottomBlur()
    }
}

// MARK: - Preview

#if DEBUG
    import SwiftUI

    @available(iOS 17.0, *)
    #Preview {
        UINavigationController(
            rootViewController: SimilarPhotosViewController(assets: [], monthTitle: "January", monthKey: "2024-01"))
    }
#endif

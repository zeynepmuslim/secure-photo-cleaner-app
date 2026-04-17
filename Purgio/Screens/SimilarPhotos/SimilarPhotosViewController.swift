//
//  SimilarPhotosViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import SwiftUI
import UIKit

private enum Strings {
    static let scanningMessage = NSLocalizedString("similarPhotos.scanningMessage", comment: "Scanning for similar photos progress message")
    static let similarPhotosTitle = NSLocalizedString("similarPhotos.title", comment: "Similar photos screen title")
    static let cancel = CommonStrings.cancel
    static let noSimilarTitle = NSLocalizedString("similarPhotos.noSimilarTitle", comment: "No similar photos found title")
    static let noSimilarMessage = NSLocalizedString("similarPhotos.noSimilarMessage", comment: "No similar photos found message")
    static let scanAgain = NSLocalizedString("similarPhotos.scanAgain", comment: "Scan again button")
    static let tryAnotherMonth = NSLocalizedString("similarPhotos.tryAnotherMonth", comment: "Try another month button")
    static let photosAccessDenied = NSLocalizedString("similarPhotos.photosAccessDenied", comment: "Photos access denied message")
    static let alreadyProcessedTitle = NSLocalizedString("similarPhotos.alreadyProcessedTitle", comment: "Already processed alert title")
    static let alreadyProcessedMessage = NSLocalizedString("similarPhotos.alreadyProcessedMessage", comment: "Already processed alert message")
    static let confirmTitle = NSLocalizedString("similarPhotos.confirmTitle", comment: "Confirm actions alert title")
    static let confirm = NSLocalizedString("similarPhotos.confirm", comment: "Confirm button")
    static let ok = CommonStrings.ok
    static func similarPhotosNavTitle(month: String) -> String {
        String(format: NSLocalizedString("similarPhotos.navTitle", comment: "Similar photos nav title with month"), month)
    }
    static func confirmMessage(keepCount: Int, deleteCount: Int, storeCount: Int) -> String {
        var parts: [String] = []
        if keepCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.keepCount", comment: "Keep photo count, e.g. 'Keep 3 photos'"), keepCount))
        }
        if deleteCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.deleteCount", comment: "Delete photo count, e.g. 'Delete 2 photos'"), deleteCount))
        }
        if storeCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.storeCount", comment: "Store photo count, e.g. 'Store 1 photo'"), storeCount))
        }
        return parts.joined(separator: "\n")
    }
    static let batchConfirmTitle = NSLocalizedString("similarPhotos.batchConfirmTitle", comment: "Confirm all groups title")
    static let batchConfirmAction = NSLocalizedString("similarPhotos.batchConfirmAction", comment: "Add to bin button")
    static let noUnprocessedGroups = NSLocalizedString("similarPhotos.noUnprocessedGroups", comment: "All groups processed message")
    static let batchBinTitle = NSLocalizedString("similarPhotos.batchBinTitle", comment: "Batch confirm title")
    static func batchConfirmMessage(keepCount: Int, deleteCount: Int, storeCount: Int, groupCount: Int) -> String {
        var parts: [String] = []
        if keepCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.keepCount", comment: "Keep photo count"), keepCount))
        }
        if deleteCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.deleteCount", comment: "Delete photo count"), deleteCount))
        }
        if storeCount > 0 {
            parts.append(String.localizedStringWithFormat(NSLocalizedString("similarPhotos.storeCount", comment: "Store photo count"), storeCount))
        }
        let fromGroups = String.localizedStringWithFormat(NSLocalizedString("similarPhotos.fromGroups", comment: "From group count, e.g. 'From 3 groups'"), groupCount)
        return parts.joined(separator: "\n") + "\n\n" + fromGroups
    }
}

class SimilarPhotosViewController: UIViewController {

    private struct UndoAction {
        let groupIndex: Int
        let deletedAssets: [PHAsset]
        let keptAssets: [PHAsset]
        let storedAssets: [PHAsset]
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(SimilarGroupCell.self, forCellReuseIdentifier: SimilarGroupCell.reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
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

    private let emptyStateView = EmptyStateView()

    private let photoLibraryService = PhotoLibraryService.shared

    private var similarGroups: [SimilarAssetGroup] = []
    private var assets: [PHAsset]?
    private let monthTitle: String?
    private let monthKey: String?
    private let mediaType: PHAssetMediaType

    private var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

    private var processedGroupIndexes = Set<Int>()

    private var processedActions: [Int: UndoAction] = [:]

    private var groupAssetStates: [Int: [String: SimilarGroupCell.PhotoState]] = [:]

    private var scrollStartOffset: CGFloat = 0

    private var lastBatchConfirmedIndices: [Int] = []

    private var compactMonthString: String? {
        guard let key = monthKey else { return nil }
        return DateFormatterManager.shared.compactMonth(fromMonthKey: key)
    }

    var navigationSource: NavigationSource = .manual

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

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupConstraint()
        setupNavigationBar()

        if let compactMonth = compactMonthString {
            title = Strings.similarPhotosNavTitle(month: compactMonth)
        } else {
            title = Strings.similarPhotosTitle
        }

        showSkeletonLoading()
        tableView.isHidden = true
    }

    func didTapUndo(cell: SimilarGroupCell) {
        guard let indexPath = tableView.indexPath(for: cell),
            let action = processedActions[indexPath.row]
        else { return }

        let group = similarGroups[indexPath.row]
        let signature = getSignature(for: group)

        // Revert Deletions
        DeleteBinStore.shared.removeAssetIds(action.deletedAssets.map(\.localIdentifier))

        // Revert deletion stats
        for asset in action.deletedAssets {
            let resources = PHAssetResource.assetResources(for: asset)
            let bytes = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
            StatsStore.shared.undoDeletion(for: asset.mediaType, bytes: bytes)
        }

        // Revert Kept
        KeptAssetsStore.shared.removeAssetIds(action.keptAssets.map(\.localIdentifier))

        // Revert Stored
        WillBeStoredStore.shared.removeAssetIds(action.storedAssets.map(\.localIdentifier))
        for asset in action.storedAssets {
            Task {
                _ = await photoLibraryService.removeAssetFromWillBeStoredAlbum(asset: asset)
            }
        }

        // Revert review stats for all assets in the group
        for asset in action.deletedAssets + action.keptAssets + action.storedAssets {
            StatsStore.shared.undoReview(for: asset.mediaType)
        }

        // Revert Processed State
        processedGroupIndexes.remove(action.groupIndex)
        processedActions.removeValue(forKey: action.groupIndex)

        // Remove from Persistence
        SimilarUndoStore.shared.removeAction(forGroupSignature: signature)

        // Revert Progress
        let totalReverted = action.deletedAssets.count + action.keptAssets.count + action.storedAssets.count
        revertProgress(
            deletedCount: action.deletedAssets.count,
            keptCount: action.keptAssets.count,
            storedCount: action.storedAssets.count,
            totalProcessedCount: totalReverted
        )

        HapticFeedbackManager.shared.impact(intensity: .medium)

        cell.configureForProcessedState(isProcessed: false)

        lastBatchConfirmedIndices.removeAll { $0 == indexPath.row }
        configureGlobalBinButton()
    }

    func didTapConfirm(cell: SimilarGroupCell) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }

        if processedGroupIndexes.contains(indexPath.row) {
            HapticFeedbackManager.shared.warning()
            showAlert(title: Strings.alreadyProcessedTitle, message: Strings.alreadyProcessedMessage)
            return
        }

        let (keep, delete, store) = cell.getAssetsByState()

        HapticFeedbackManager.shared.impact(intensity: .light)
        processGroup(at: indexPath.row, keeping: keep, deleting: delete, storing: store)
        configureGlobalBinButton()
    }

    private func processGroup(at index: Int, keeping: [PHAsset], deleting: [PHAsset], storing: [PHAsset]) {
        guard index < similarGroups.count else { return }

        let group = similarGroups[index]
        let signature = getSignature(for: group)

        DeleteBinStore.shared.addAssetIds(deleting.map(\.localIdentifier))

        // Record deletion stats for each asset marked for deletion
        for asset in deleting {
            let resources = PHAssetResource.assetResources(for: asset)
            let bytes = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
            StatsStore.shared.recordDeletion(for: asset.mediaType, bytes: bytes)
        }

        // Record review stats for all assets in the group (keep + delete + store = all reviewed)
        for asset in keeping + deleting + storing {
            StatsStore.shared.recordReview(for: asset.mediaType)
        }

        KeptAssetsStore.shared.addAssetIds(keeping.map(\.localIdentifier))

        WillBeStoredStore.shared.addAssetIds(storing.map(\.localIdentifier))
        for asset in storing {
            Task {
                _ = await photoLibraryService.addAssetToWillBeStoredAlbum(asset: asset)
            }
        }

        // Mark as processed
        processedGroupIndexes.insert(index)

        // Update Progress
        updateProgress(
            deletedCount: deleting.count,
            keptCount: keeping.count,
            storedCount: storing.count,
            totalProcessedCount: group.assets.count
        )

        // Record Action for Undo
        let action = UndoAction(
            groupIndex: index,
            deletedAssets: deleting,
            keptAssets: keeping,
            storedAssets: storing
        )
        processedActions[index] = action

        // Persist Action
        let persisted = PersistedUndoAction(
            groupSignature: signature,
            deletedIds: deleting.map { $0.localIdentifier },
            keptIds: keeping.map { $0.localIdentifier },
            storedIds: storing.map { $0.localIdentifier },
            timestamp: Date()
        )
        SimilarUndoStore.shared.saveAction(persisted)

        HapticFeedbackManager.shared.success()

        if let cell = tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? SimilarGroupCell {
            cell.configureForProcessedState(isProcessed: true)
        }
    }

    private func configureGlobalBinButton() {
        // Show "Undo All" if there are still batch-confirmed groups
        if !lastBatchConfirmedIndices.isEmpty {
            binController?.configureWideBinButton(
                title: NSLocalizedString("similarPhotos.undoAll", comment: "Undo all button"),
                monthKey: monthKey,
                monthTitle: monthTitle,
                tapHandler: { [weak self] in self?.handleBatchUndo() }
            )
            binController?.showBinButton()
            return
        }

        let unprocessedIndices = similarGroups.indices.filter { !processedGroupIndexes.contains($0) }
        let deleteCount = unprocessedIndices.reduce(0) { sum, index in
            let states = groupAssetStates[index] ?? [:]
            return sum + states.values.filter { $0 == .delete }.count
        }

        if deleteCount > 0 {
            binController?.configureWideBinButton(
                title: Strings.batchBinTitle,
                monthKey: monthKey,
                monthTitle: monthTitle,
                tapHandler: { [weak self] in self?.handleBatchConfirm() }
            )
            binController?.showBinButton()
        } else {
            // All processed — revert to default. navigate to DeleteBinVC
            binController?.configureBinButton(
                mode: .count(DeleteBinStore.shared.count),
                monthKey: monthKey,
                monthTitle: monthTitle,
                tapHandler: nil
            )
        }
    }

    private func handleBatchConfirm() {
        let unprocessedIndices = similarGroups.indices.filter { !processedGroupIndexes.contains($0) }

        guard !unprocessedIndices.isEmpty else {
            showAlert(title: Strings.alreadyProcessedTitle, message: Strings.noUnprocessedGroups)
            return
        }

        var totalKeep = 0
        var totalDelete = 0
        var totalStore = 0
        for index in unprocessedIndices {
            let states = groupAssetStates[index] ?? [:]
            for state in states.values {
                switch state {
                case .keep: totalKeep += 1
                case .delete: totalDelete += 1
                case .store: totalStore += 1
                }
            }
        }

        let alert = UIAlertController(
            title: Strings.batchConfirmTitle,
            message: Strings.batchConfirmMessage(
                keepCount: totalKeep, deleteCount: totalDelete,
                storeCount: totalStore, groupCount: unprocessedIndices.count),
            preferredStyle: .alert
        )
        alert.addAction(
            UIAlertAction(title: Strings.cancel, style: .cancel) { _ in
                HapticFeedbackManager.shared.impact(intensity: .light)
            })
        alert.addAction(
            UIAlertAction(title: Strings.batchConfirmAction, style: .destructive) { [weak self] _ in
                self?.executeBatchConfirm()
            })
        present(alert, animated: true)
    }

    private func executeBatchConfirm() {
        var batchIndices: [Int] = []
        for (index, group) in similarGroups.enumerated() {
            guard !processedGroupIndexes.contains(index) else { continue }

            let states = groupAssetStates[index] ?? [:]
            var keeping: [PHAsset] = []
            var deleting: [PHAsset] = []
            var storing: [PHAsset] = []

            for asset in group.assets {
                switch states[asset.localIdentifier] ?? .delete {
                case .keep: keeping.append(asset)
                case .delete: deleting.append(asset)
                case .store: storing.append(asset)
                }
            }

            processGroup(at: index, keeping: keeping, deleting: deleting, storing: storing)
            batchIndices.append(index)
        }

        lastBatchConfirmedIndices = batchIndices
        tableView.reloadData()

        if !batchIndices.isEmpty {
            binController?.configureWideBinButton(
                title: NSLocalizedString("similarPhotos.undoAll", comment: "Undo all button"),
                monthKey: monthKey,
                monthTitle: monthTitle,
                tapHandler: { [weak self] in self?.handleBatchUndo() }
            )
        } else {
            configureGlobalBinButton()
        }
    }

    private func handleBatchUndo() {
        let indices = lastBatchConfirmedIndices
        guard !indices.isEmpty else { return }

        var allDeletedIds: [String] = []
        var allKeptIds: [String] = []
        var allStoredAssets: [PHAsset] = []

        for index in indices {
            guard let action = processedActions[index] else { continue }
            let group = similarGroups[index]
            let signature = getSignature(for: group)

            allDeletedIds.append(contentsOf: action.deletedAssets.map(\.localIdentifier))
            allKeptIds.append(contentsOf: action.keptAssets.map(\.localIdentifier))
            allStoredAssets.append(contentsOf: action.storedAssets)

            for asset in action.deletedAssets {
                let resources = PHAssetResource.assetResources(for: asset)
                let bytes = resources.first?.value(forKey: "fileSize") as? Int64 ?? 0
                StatsStore.shared.undoDeletion(for: asset.mediaType, bytes: bytes)
            }

            for asset in action.deletedAssets + action.keptAssets + action.storedAssets {
                StatsStore.shared.undoReview(for: asset.mediaType)
            }

            revertProgress(
                deletedCount: action.deletedAssets.count,
                keptCount: action.keptAssets.count,
                storedCount: action.storedAssets.count,
                totalProcessedCount: action.deletedAssets.count + action.keptAssets.count + action.storedAssets.count
            )

            SimilarUndoStore.shared.removeAction(forGroupSignature: signature)
            processedGroupIndexes.remove(index)
            processedActions.removeValue(forKey: index)
        }

        DeleteBinStore.shared.removeAssetIds(allDeletedIds)
        KeptAssetsStore.shared.removeAssetIds(allKeptIds)
        WillBeStoredStore.shared.removeAssetIds(allStoredAssets.map(\.localIdentifier))
        for asset in allStoredAssets {
            Task { _ = await photoLibraryService.removeAssetFromWillBeStoredAlbum(asset: asset) }
        }

        lastBatchConfirmedIndices = []

        HapticFeedbackManager.shared.impact(intensity: .medium)
        tableView.reloadData()
        configureGlobalBinButton()
    }

    private func revertProgress(deletedCount: Int, keptCount: Int, storedCount: Int, totalProcessedCount: Int) {
        guard let monthKey = monthKey else { return }

        let similarKey = "\(monthKey)_similar"
        let currentSimilar = ReviewProgressStore.shared.getProgress(forMonthKey: similarKey, mediaType: mediaType)
        let currentMain = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)

        // Batch: single persist for both keys
        ReviewProgressStore.shared.batchSave([
            (monthKey: similarKey, mediaType: mediaType,
             currentIndex: max(0, currentSimilar.currentIndex - totalProcessedCount),
             reviewedCount: max(0, currentSimilar.reviewedCount - totalProcessedCount),
             deletedCount: max(0, currentSimilar.deletedCount - deletedCount),
             keptCount: max(0, currentSimilar.keptCount - keptCount),
             storedCount: max(0, currentSimilar.storedCount - storedCount),
             originalTotalCount: currentSimilar.originalTotalCount),
            (monthKey: monthKey, mediaType: mediaType,
             currentIndex: currentMain.currentIndex,
             reviewedCount: max(0, currentMain.reviewedCount - totalProcessedCount),
             deletedCount: max(0, currentMain.deletedCount - deletedCount),
             keptCount: max(0, currentMain.keptCount - keptCount),
             storedCount: max(0, currentMain.storedCount - storedCount),
             originalTotalCount: currentMain.originalTotalCount)
        ])
    }

    private func setupNavigationBar() {
        let helpButton = HelpButton()
        helpButton.addTarget(self, action: #selector(handleHelpTap), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: helpButton)
    }

    @objc private func handleHelpTap() {
        HapticFeedbackManager.shared.impact(intensity: .light)
        let helpSheet = SimilarPhotosHelpSheet()
        present(helpSheet, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        exitStoreModeOnAllCells()
        lastBatchConfirmedIndices = []
        if isMovingFromParent {
            binController?.hideBinButton()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Reconfigure bin button in case it was reset during navigation
        if !similarGroups.isEmpty {
            configureGlobalBinButton()
        }

        guard similarGroups.isEmpty else { return }
        if assets != nil {
            runScan()
        } else if monthKey != nil {
            fetchAssetsForScan()
        }
    }

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

    private func getSignature(for group: SimilarAssetGroup) -> String {
        return group.assets.map { $0.localIdentifier }.sorted().joined(separator: "|")
    }

    private func setupUI() {
        view.backgroundColor = .mainBackground

        view.addSubview(tableView)
        view.addSubview(activityIndicator)
        view.addSubview(statusLabel)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: GeneralConstants.EdgePadding.medium),
            tableView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -GeneralConstants.EdgePadding.medium),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),

            statusLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40)
        ])
    }

    private func showSkeletonLoading() {
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        tableView.isHidden = true

        if skeletonListView == nil {
            let skeleton = SkeletonListView(rowCount: 5)
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(skeleton)
            self.skeletonListView = skeleton

            NSLayoutConstraint.activate([
                skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                skeleton.leadingAnchor.constraint(
                    equalTo: view.leadingAnchor, constant: GeneralConstants.EdgePadding.medium),
                skeleton.trailingAnchor.constraint(
                    equalTo: view.trailingAnchor, constant: -GeneralConstants.EdgePadding.medium),
                skeleton.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }

        skeletonListView?.isHidden = false
        skeletonListView?.startAnimating()
    }

    private func hideSkeletonLoading() {
        skeletonListView?.stopAnimating()
        skeletonListView?.isHidden = true
    }

    private func startScan() {
        showSkeletonLoading()
        tableView.isHidden = true

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
//            print("[SimilarPhotos] scan completed, \(groups.count) groups found")
            self.hideSkeletonLoading()
            self.activityIndicator.stopAnimating()
            self.statusLabel.isHidden = true

            if groups.isEmpty {
                self.showEmptyState()
            } else {
                if let monthKey = self.monthKey {
                    MonthFilterStatusStore.shared.markFilterNotFinished(monthKey: monthKey, filter: .similar)
                }
                self.similarGroups = groups

                self.groupAssetStates.removeAll()
                for (index, group) in groups.enumerated() {
                    var states: [String: SimilarGroupCell.PhotoState] = [:]
                    for asset in group.assets {
                        if asset.localIdentifier == group.bestAsset?.localIdentifier {
                            states[asset.localIdentifier] = .keep
                        } else {
                            states[asset.localIdentifier] = .delete
                        }
                    }
                    self.groupAssetStates[index] = states
                }

                self.processedGroupIndexes.removeAll()
                self.processedActions.removeAll()

                for (index, group) in groups.enumerated() {
                    let signature = self.getSignature(for: group)
                    if let persisted = SimilarUndoStore.shared.getAction(forGroupSignature: signature) {

                        let deletedAssets = group.assets.filter { persisted.deletedIds.contains($0.localIdentifier) }
                        let keptAssets = group.assets.filter { persisted.keptIds.contains($0.localIdentifier) }
                        let storedAssets = group.assets.filter { persisted.storedIds.contains($0.localIdentifier) }

                        let action = UndoAction(
                            groupIndex: index,
                            deletedAssets: deletedAssets,
                            keptAssets: keptAssets,
                            storedAssets: storedAssets
                        )

                        self.processedActions[index] = action
                        self.processedGroupIndexes.insert(index)
                    }
                }

                self.tableView.isHidden = false
                self.tableView.reloadData()
                self.configureGlobalBinButton()

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
    }

    private func showEmptyState() {
        hideSkeletonLoading()

        if let monthKey = monthKey {
            MonthFilterStatusStore.shared.markFilterFinished(monthKey: monthKey, filter: .similar)
        }

        let showTryAnother = navigationSource == .dashboard || navigationSource == .luckyPicker

        if showTryAnother {
            emptyStateView.configure(
                icon: "photo.stack",
                iconColor: .systemGreen,
                title: Strings.noSimilarTitle,
                message: Strings.noSimilarMessage,
                actionTitle: Strings.tryAnotherMonth,
                onAction: { [weak self] in self?.tryAnotherMonth() }
            )
        } else {
            emptyStateView.configure(
                icon: "photo.stack",
                iconColor: .systemGreen,
                title: Strings.noSimilarTitle,
                message: Strings.noSimilarMessage,
                actionTitle: Strings.scanAgain,
                onAction: { [weak self] in self?.startScan() }
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
        activityIndicator.stopAnimating()
        statusLabel.isHidden = true
        tableView.isHidden = true
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

        guard let nav = navigationController else { return }
        var vcs = nav.viewControllers
        vcs.removeLast()
        vcs.append(newVC)
        nav.setViewControllers(vcs, animated: true)
    }

    private func showPermissionError() {
        hideSkeletonLoading()
        activityIndicator.stopAnimating()
        statusLabel.text = Strings.photosAccessDenied
        statusLabel.isHidden = false
    }
}

// MARK: - Store Mode Dismissal
extension SimilarPhotosViewController {

    private func exitStoreModeOnAllCells() {
        for cell in tableView.visibleCells {
            (cell as? SimilarGroupCell)?.exitStoreModeIfNeeded()
        }
    }
}

// MARK: - TableView
extension SimilarPhotosViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return similarGroups.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =
            tableView.dequeueReusableCell(withIdentifier: SimilarGroupCell.reuseIdentifier, for: indexPath)
            as! SimilarGroupCell
        let group = similarGroups[indexPath.row]
        cell.configure(with: group, index: indexPath.row)
        cell.delegate = self

        if groupAssetStates[indexPath.row] == nil {
            groupAssetStates[indexPath.row] = cell.getCurrentAssetStates()
        }

        let isProcessed = processedGroupIndexes.contains(indexPath.row)
        cell.configureForProcessedState(isProcessed: isProcessed)

        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 240
    }

    // MARK: - ScrollView Delegate

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollStartOffset = scrollView.contentOffset.y
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let delta = abs(scrollView.contentOffset.y - scrollStartOffset)
        if delta > 30 {
            exitStoreModeOnAllCells()
        }
    }
}

// MARK: - Cell Delegate
extension SimilarPhotosViewController: SimilarGroupCellDelegate {

    func didInteractWithCell(_ cell: SimilarGroupCell) { // just one active store mode cell
        for visibleCell in tableView.visibleCells {
            guard let groupCell = visibleCell as? SimilarGroupCell,
                groupCell !== cell
            else { continue }
            groupCell.exitStoreModeIfNeeded()
        }
    }

    func didChangeAssetStates(_ cell: SimilarGroupCell, states: [String: SimilarGroupCell.PhotoState]) {
        guard let indexPath = tableView.indexPath(for: cell) else { return }
        groupAssetStates[indexPath.row] = states
        configureGlobalBinButton()
    }

    private func updateProgress(deletedCount: Int, keptCount: Int, storedCount: Int, totalProcessedCount: Int) {
        guard let monthKey = monthKey else { return }

        let similarKey = "\(monthKey)_similar"
        let currentSimilar = ReviewProgressStore.shared.getProgress(forMonthKey: similarKey, mediaType: mediaType)
        let currentMain = ReviewProgressStore.shared.getProgress(forMonthKey: monthKey, mediaType: mediaType)

        // Batch: single persist for both keys
        ReviewProgressStore.shared.batchSave([
            (monthKey: similarKey, mediaType: mediaType,
             currentIndex: currentSimilar.currentIndex + totalProcessedCount,
             reviewedCount: currentSimilar.reviewedCount + totalProcessedCount,
             deletedCount: currentSimilar.deletedCount + deletedCount,
             keptCount: currentSimilar.keptCount + keptCount,
             storedCount: currentSimilar.storedCount + storedCount,
             originalTotalCount: currentSimilar.originalTotalCount),
            (monthKey: monthKey, mediaType: mediaType,
             currentIndex: currentMain.currentIndex,
             reviewedCount: currentMain.reviewedCount + totalProcessedCount,
             deletedCount: currentMain.deletedCount + deletedCount,
             keptCount: currentMain.keptCount + keptCount,
             storedCount: currentMain.storedCount + storedCount,
             originalTotalCount: currentMain.originalTotalCount)
        ])

        let newReviewedCount = currentMain.reviewedCount + totalProcessedCount
        ReminderDataCenter.shared.markSimilarReviewActivity(
            monthKey: monthKey,
            mediaType: mediaType,
            reviewedCount: newReviewedCount,
            totalCount: currentMain.originalTotalCount
        )
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        present(alert, animated: true)
    }
}

@available(iOS 17.0, *)
#Preview {
    UINavigationController(
        rootViewController: SimilarPhotosViewController(assets: [], monthTitle: "January", monthKey: "2024-01"))
}

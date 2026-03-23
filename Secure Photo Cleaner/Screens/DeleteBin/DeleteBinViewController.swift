//
//  DeleteBinViewController.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 04.01.2026.
//

import Photos
import SwiftUI
import UIKit

private enum Strings {
    static let navTitle = "Delete Bin"
    static let editMode = "Edit Mode"
    static let goToGeneralBin = "Go To General Bin"
    static let remove = CommonStrings.remove
    static let cancel = CommonStrings.cancel
    static let delete = CommonStrings.delete
    static let ok = CommonStrings.ok
    static let deletingProgress = "Deleting..."
    static let deleteCannotUndo = "Items will be moved to the \"Recently Deleted\" folder in your Photos library, where you can recover them for up to 30 days."
    static let yourDeleteBin = "Your Delete Bin"
    static let deleteBinEmptyMessage =
        "This is where photos you want to delete will be collected.\n\nSwipe left on any photo during review to add it here. When you're ready, tap \"Delete All\" to permanently remove them."
    static let successTitle = "Success!"
    static let allDeletedMessage = "All items have been moved to the \"Recently Deleted\" folder."
    static let errorTitle = "Something went wrong"
    static let errorMessage = "Unable to delete items. Please try again."

    private static func mediaDescription(for assets: [PHAsset]) -> String {
        let photoCount = assets.filter { $0.mediaType == .image }.count
        let videoCount = assets.filter { $0.mediaType == .video }.count

        switch (photoCount, videoCount) {
        case (let p, 0): return "\(p) photo\(p == 1 ? "" : "s")"
        case (0, let v): return "\(v) video\(v == 1 ? "" : "s")"
        case (let p, let v):
            return "\(p) photo\(p == 1 ? "" : "s") and \(v) video\(v == 1 ? "" : "s")"
        }
    }

    static func removeConfirmTitle(assets: [PHAsset]) -> String {
        "Remove \(mediaDescription(for: assets))?"
    }
    static func removeConfirmMessage(assets: [PHAsset]) -> String {
        "\(assets.count == 1 ? "This item" : "These items") will be restored and won't be deleted."
    }
    static func deleteConfirmTitle(assets: [PHAsset]) -> String {
        "Delete \(mediaDescription(for: assets))?"
    }
    static func photoCount(assets: [PHAsset]) -> String {
        mediaDescription(for: assets)
    }
    static func photoCountWithSize(assets: [PHAsset], size: String) -> String {
        "\(mediaDescription(for: assets)) · ~\(size)"
    }
    static func monthBinTitle(monthTitle: String) -> String {
        "\(monthTitle) Bin"
    }
    static func binCountTitle(count: Int) -> String {
        "Bin · \(count)"
    }
    static let allCleanedTitle = "All Cleaned Up!"
    static let goBack = "Go Back"
    static func freshEmptyMessage(assets: [PHAsset], size: String) -> String {
        "You freed up \(size) by deleting \(mediaDescription(for: assets))."
    }
    static func freshEmptyMessageNoSize(assets: [PHAsset]) -> String {
        "You deleted \(mediaDescription(for: assets)) from your library."
    }
}

final class DeleteBinViewController: UIViewController {

    var filterMonthKey: String?   // Optional filter: "yyyy-MM""2024-01"
    var filterMonthTitle: String?   // Optional title: "January 2025"

    private let headerLabel: PaddingLabel = {
        let label = PaddingLabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        label.layer.cornerRadius = 16
        label.layer.masksToBounds = true
        return label
    }()

    private let emptyStateView = EmptyStateView()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        layout.sectionInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(PhotoThumbnailCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.allowsMultipleSelection = false
        collectionView.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 100, right: 0)
        collectionView.scrollIndicatorInsets = collectionView.contentInset
        return collectionView
    }()

    private lazy var doneBarButtonItem: UIBarButtonItem = {
        let action = UIAction { [weak self] _ in
            self?.setEditing(false, animated: true)
        }
        return UIBarButtonItem(systemItem: .done, primaryAction: action)
    }()

    private let removeSelectedButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: Strings.remove,
            systemImage: "trash.slash",
            style: .prominent,
            backgroundColor: .systemBlue
        )
        return button
    }()

    private let editButtonsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .fill
        stack.distribution = .fill
        stack.spacing = GeneralConstants.EdgePadding.medium
        stack.alpha = 0
        stack.isHidden = true
        return stack
    }()

    private let binSpacerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        return view
    }()

    private let deleteBinStore = DeleteBinStore.shared
    private let storageManager = StorageAnalysisManager.shared
    private let photoLibraryService = PhotoLibraryService.shared

    private var photoAssets: [PHAsset] = []
    private var thumbnailSize: CGSize = .zero

    private enum EmptyKind {
        case defaultEmpty
        case freshEmpty(assets: [PHAsset], bytes: Int64)
    }
    private var pendingEmptyKind: EmptyKind = .defaultEmpty

    private var isEditMode = false
    private var binSpacerWidthConstraint: NSLayoutConstraint?
    private var collectionViewBottomConstraint: NSLayoutConstraint!
    private var needsReload = true
    private var isLoadingPhotos = false
    private var isPreviewOpen = false
    private var skeletonGridView: SkeletonGridView?
    private var skipAutoLoad = false

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = Strings.navTitle
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never

        setupNavigationItems()
        setupUI()
        setupConstraint()
        calculateThumbnailSize()

        if skipAutoLoad {
            updateUI()
        } else {
            loadPhotos()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if needsReload && !isLoadingPhotos && !skipAutoLoad {
            loadPhotos()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateBinSpacerWidth(animated: false)
        headerLabel.layer.cornerRadius = headerLabel.bounds.height / 2
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.updateBinSpacerWidth(animated: false)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isEditMode {
            setEditing(false, animated: false)
        }
        findFloatingBinButton()?.isEnabled = true
        findFloatingBinButton()?.alpha = 1.0
    }

    private func setupUI() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeleteAll),
            name: .deleteBinButtonTapped,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deleteBinCountDidChange),
            name: .deleteBinCountDidChange,
            object: nil
        )

        removeSelectedButton.addTarget(self, action: #selector(handleRemoveSelected), for: .touchUpInside)

        collectionView.delegate = self
        collectionView.dataSource = self
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)

        view.addSubview(collectionView)
        view.addSubview(emptyStateView)
        view.addSubview(headerLabel)

        editButtonsStack.addArrangedSubview(removeSelectedButton)
        editButtonsStack.addArrangedSubview(binSpacerView)
        view.addSubview(editButtonsStack)

        emptyStateView.isHidden = true

        view.bringSubviewToFront(headerLabel)
        view.bringSubviewToFront(editButtonsStack)
    }

    private func setupConstraint() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        emptyStateView.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        editButtonsStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headerLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            headerLabel.heightAnchor.constraint(equalToConstant: 32),

            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            editButtonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            editButtonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            editButtonsStack.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -GeneralConstants.Spacer.buttonBottom),
            editButtonsStack.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            removeSelectedButton.widthAnchor.constraint(equalTo: binSpacerView.widthAnchor)
        ])

        binSpacerWidthConstraint = binSpacerView.widthAnchor.constraint(equalToConstant: 0)
        binSpacerWidthConstraint?.priority = .defaultLow
        binSpacerWidthConstraint?.isActive = true

        collectionViewBottomConstraint = collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        collectionViewBottomConstraint.isActive = true
    }

    private func setupNavigationItems() {
        if filterMonthKey != nil {
            let menuButton = UIButton(type: .system)
            menuButton.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
            menuButton.tintColor = .label
            menuButton.showsMenuAsPrimaryAction = true
            menuButton.menu = makeEditMenu()
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: menuButton)
        } else {
            let editButton = UIBarButtonItem(
                image: UIImage(systemName: "pencil"),
                style: .plain,
                target: self,
                action: #selector(handleEditTap)
            )
            navigationItem.rightBarButtonItem = editButton
        }
    }

    private func makeEditMenu() -> UIMenu {
        let editAction = UIAction(
            title: Strings.editMode,
            image: UIImage(systemName: "pencil")
        ) { [weak self] _ in
            self?.handleEditTap()
        }
        let showAllAction = UIAction(
            title: Strings.goToGeneralBin,
            image: UIImage(systemName: "tray.full")
        ) { [weak self] _ in
            self?.handleShowWholeBin()
        }
        return UIMenu(title: "", children: [editAction, showAllAction])
    }

    @objc private func handleShowWholeBin() {
        let generalBinVC = DeleteBinViewController()
        navigationController?.pushViewController(generalBinVC, animated: true)
    }

    // MARK: - Edit Mode
    @objc private func handleEditTap() {
        setEditing(true, animated: true)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)

        isEditMode = editing
        collectionView.allowsMultipleSelection = editing

        if animated {
            if editing {
                editButtonsStack.isHidden = false
                editButtonsStack.alpha = 0
                editButtonsStack.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                UIView.animate(
                    withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.8, options: []
                ) {
                    self.editButtonsStack.alpha = 1
                    self.editButtonsStack.transform = .identity
                }
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
                    self.editButtonsStack.alpha = 0
                    self.editButtonsStack.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                } completion: { _ in
                    self.editButtonsStack.isHidden = true
                    self.editButtonsStack.transform = .identity
                }
            }
        } else {
            editButtonsStack.alpha = editing ? 1 : 0
            editButtonsStack.isHidden = !editing
            editButtonsStack.transform = .identity
        }

        if !editing {
            if let selectedItems = collectionView.indexPathsForSelectedItems {
                for indexPath in selectedItems {
                    collectionView.deselectItem(at: indexPath, animated: animated)
                }
            }
        }

        if editing {
            navigationItem.rightBarButtonItem = doneBarButtonItem
        } else {
            setupNavigationItems()
        }

        updateEditModeButtonsState()
        notifyEditStateChange()
        updateBinSpacerWidth(animated: true)

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.isEmpty {
            collectionView.reloadItems(at: visibleIndexPaths)
        }
    }

    private func updateEditModeButtonsState() {
        let hasSelection = collectionView.indexPathsForSelectedItems?.isEmpty == false
        removeSelectedButton.isEnabled = hasSelection

        notifyEditStateChange()
        updateBinSpacerWidth(animated: true)
    }

    private func updateBinSpacerWidth(animated: Bool) {
        guard let binButton = findFloatingBinButton() else {
            binSpacerWidthConstraint?.constant = 0
            return
        }
        let isVisible = !binButton.isHidden && binButton.alpha > 0.01
        let measuredWidth = max(binButton.bounds.width, binButton.intrinsicContentSize.width)
        binSpacerWidthConstraint?.constant = isVisible ? measuredWidth : 0

        let animations = {
            self.editButtonsStack.layoutIfNeeded()
        }

        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut) {
                animations()
            }
        } else {
            animations()
        }
    }

    private func findFloatingBinButton() -> FloatingBinButton? {
        guard let rootView = tabBarController?.view else { return nil }
        return findFloatingBinButton(in: rootView)
    }

    private func findFloatingBinButton(in view: UIView) -> FloatingBinButton? {
        if let button = view as? FloatingBinButton {
            return button
        }
        for subview in view.subviews {
            if let match = findFloatingBinButton(in: subview) {
                return match
            }
        }
        return nil
    }

    private func notifyEditStateChange() {
        let selectedCount = collectionView.indexPathsForSelectedItems?.count ?? 0
        NotificationCenter.default.post(
            name: .deleteBinEditStateDidChange,
            object: nil,
            userInfo: [
                "isEditMode": isEditMode,
                "selectedCount": selectedCount
            ]
        )
    }

    // MARK: - Actions
    @objc private func handleRemoveSelected() {
        guard let selectedItems = collectionView.indexPathsForSelectedItems, !selectedItems.isEmpty else { return }

        let selectedAssets = selectedItems.map { photoAssets[$0.item] }
        let alert = UIAlertController(
            title: Strings.removeConfirmTitle(assets: selectedAssets),
            message: Strings.removeConfirmMessage(assets: selectedAssets),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Strings.cancel, style: .cancel))
        alert.addAction(
            UIAlertAction(title: Strings.remove, style: .default) { [weak self] _ in
                self?.performRemoveSelected(selectedItems)
            })

        present(alert, animated: true)
    }

    @objc private func handleDeleteSelected() {
        guard let selectedItems = collectionView.indexPathsForSelectedItems, !selectedItems.isEmpty else { return }

        let selectedAssets = selectedItems.map { photoAssets[$0.item] }

        let alert = UIAlertController(
            title: Strings.deleteConfirmTitle(assets: selectedAssets),
            message: Strings.deleteCannotUndo,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Strings.cancel, style: .cancel))
        alert.addAction(
            UIAlertAction(title: Strings.delete, style: .destructive) { [weak self] _ in
                self?.performBatchDeletion(assets: selectedAssets, indexPaths: selectedItems)
            })

        present(alert, animated: true)
    }

    private func performRemoveSelected(_ indexPaths: [IndexPath]) {
        let sortedIndexPaths = indexPaths.sorted { $0.item > $1.item }

        let idsToRemove = sortedIndexPaths.map { photoAssets[$0.item].localIdentifier }
        deleteBinStore.removeAssetIds(idsToRemove)

        for indexPath in sortedIndexPaths {
            photoAssets.remove(at: indexPath.item)
        }

        if photoAssets.isEmpty {
            updateUI()
        } else {
            collectionView.deleteItems(at: indexPaths)
            updateHeader()
        }

        if isEditMode {
            setEditing(false, animated: true)
        }
    }

    // MARK: - UI Updates
    private func calculateThumbnailSize() {
        let columns: CGFloat = 3
        let spacing: CGFloat = 2
        let insets: CGFloat = 4
        let totalSpacing = (columns - 1) * spacing + insets
        let containerWidth = collectionView.bounds.width > 0 ? collectionView.bounds.width : view.bounds.width
        let width = (containerWidth - totalSpacing) / columns
        thumbnailSize = CGSize(width: width * UIScreen.main.scale, height: width * UIScreen.main.scale)

        if let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: width, height: width)
        }
    }

    // MARK: - Data Loading
    private func loadPhotos() {
        pendingEmptyKind = .defaultEmpty
        if isLoadingPhotos || skipAutoLoad {
            return
        }
        isLoadingPhotos = true
        showLoadingState()

        let assetIds = deleteBinStore.loadAssetIds()
        Task { [weak self] in
            guard let self = self else { return }

            guard !assetIds.isEmpty else {
                await MainActor.run {
                    self.photoAssets = []
                    self.hideLoadingState()
                    self.updateUI()
                    self.isLoadingPhotos = false
                    self.needsReload = false
                }
                return
            }

            let assets = await self.photoLibraryService.fetchAssets(withLocalIdentifiers: assetIds)

            let filterComponents = self.filterMonthKey?.split(separator: "-")
            let filterYear = filterComponents?.first.flatMap { Int($0) }
            let filterMonth = filterComponents?.last.flatMap { Int($0) }

            let filteredAssets = assets.filter { asset in
                if let fYear = filterYear, let fMonth = filterMonth, let date = asset.creationDate {
                    let components = Calendar.current.dateComponents([.year, .month], from: date)
                    return components.year == fYear && components.month == fMonth
                }
                return self.filterMonthKey == nil
            }

            await MainActor.run {
                self.photoAssets = filteredAssets
                self.hideLoadingState()
                self.updateUI()
                self.isLoadingPhotos = false
                self.needsReload = false

                if self.filterMonthKey != nil {
                    if let monthTitle = self.filterMonthTitle {
                        self.title = Strings.monthBinTitle(monthTitle: monthTitle)
                    } else {
                        self.title = Strings.binCountTitle(count: self.photoAssets.count)
                    }
                }
            }
        }
    }

    @objc private func deleteBinCountDidChange() {
        needsReload = true

        if isPreviewOpen {
            return
        }
        if isViewLoaded && view.window != nil && !isLoadingPhotos {
            loadPhotos()
        }
    }

    // MARK: - Loading State
    private func showLoadingState() {
        emptyStateView.isHidden = true
        collectionView.isHidden = true
        headerLabel.isHidden = true

        if skeletonGridView == nil {
            let skeleton = SkeletonGridView(columns: 3, rows: 5)
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(skeleton)
            self.skeletonGridView = skeleton

            NSLayoutConstraint.activate([
                skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
                skeleton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 2),
                skeleton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -2),
                skeleton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
            ])

            skeleton.startAnimating()
        }
    }

    private func hideLoadingState() {
        skeletonGridView?.fadeOut { [weak self] in
            self?.skeletonGridView = nil
        }
    }

    private func updateUI() {
        if photoAssets.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
            updateHeader()
            collectionView.reloadData()

        }
    }

    private func updateHeader() {
        let currentAssets = photoAssets

        headerLabel.text = Strings.photoCount(assets: currentAssets)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let estimatedSize = self.calculateEstimatedSize(for: currentAssets)
            let sizeString = estimatedSize.formattedBytes()

            DispatchQueue.main.async {
                if self.photoAssets.count == currentAssets.count {
                    self.headerLabel.text = Strings.photoCountWithSize(assets: currentAssets, size: sizeString)
                }
            }
        }
    }

    private func calculateEstimatedSize(for assets: [PHAsset]) -> Int64 {
        var totalSize: Int64 = 0
        for asset in assets {
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in resources {
                if let size = resource.value(forKey: "fileSize") as? Int64 {
                    totalSize += size
                }
            }
        }
        return totalSize
    }

    // MARK: - Empty State
    private func showEmptyState() {
        switch pendingEmptyKind {
        case .defaultEmpty:
            emptyStateView.configure(
                icon: "trash",
                iconColor: .systemRed,
                title: filterMonthTitle.map { Strings.monthBinTitle(monthTitle: $0) } ?? Strings.yourDeleteBin,
                message: Strings.deleteBinEmptyMessage,
                actionTitle: nil,
                onAction: nil
            )
        case .freshEmpty(let deletedAssets, let bytes):
            let message = bytes > 0
                ? Strings.freshEmptyMessage(assets: deletedAssets, size: bytes.formattedBytes())
                : Strings.freshEmptyMessageNoSize(assets: deletedAssets)
            emptyStateView.configure(
                icon: "checkmark.circle.fill",
                iconColor: .systemGreen,
                title: Strings.allCleanedTitle,
                message: message,
                actionTitle: Strings.goBack,
                onAction: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                }
            )
        }
        emptyStateView.isHidden = false
        emptyStateView.show(animated: true)
        collectionView.isHidden = true
        headerLabel.isHidden = true
        navigationItem.rightBarButtonItem?.isEnabled = false
        findFloatingBinButton()?.isEnabled = false
        findFloatingBinButton()?.alpha = 0.5
    }

    #if DEBUG
        func configureForEmptyPreview() {
            skipAutoLoad = true
        }
    #endif

    private func hideEmptyState() {
        emptyStateView.hide(animated: false)
        emptyStateView.isHidden = true
        collectionView.isHidden = false
        headerLabel.isHidden = false
        navigationItem.rightBarButtonItem?.isEnabled = true
        findFloatingBinButton()?.isEnabled = true
        findFloatingBinButton()?.alpha = 1.0
    }

    // MARK: - Preview sheeet

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }

        let asset = photoAssets[indexPath.item]
        showPreview(for: asset)
    }

    private func showPreview(for asset: PHAsset) {
        guard photoAssets.firstIndex(of: asset) != nil else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        isPreviewOpen = true
        let previewVC = MediaPreviewViewController(asset: asset)

        previewVC.onDismiss = { [weak self] in
            guard let self = self else { return }
            self.isPreviewOpen = false
            if self.needsReload {
                self.loadPhotos()
            }
        }

        previewVC.onRemove = { [weak self] in
            guard let self = self,
                let currentIndex = self.photoAssets.firstIndex(of: asset)
            else {
                return
            }
            let currentIndexPath = IndexPath(item: currentIndex, section: 0)

            self.deleteBinStore.removeAssetId(asset.localIdentifier)
            self.photoAssets.remove(at: currentIndex)

            if self.photoAssets.isEmpty {
                self.updateUI()
            } else {
                self.collectionView.deleteItems(at: [currentIndexPath])
                self.updateHeader()
            }
            print(
                "[BIN SYNC] onRemove: done, arrayCount=\(self.photoAssets.count), cvCount=\(self.collectionView.numberOfItems(inSection: 0))"
            )
        }

        // Set up undo callback
        previewVC.onUndo = { [weak self] in
            guard let self = self else { return }

            guard !self.photoAssets.contains(asset) else {
                print("[BIN SYNC] onUndo: asset already in array, skipping. arrayCount=\(self.photoAssets.count)")
                return
            }

            print(
                "[BIN SYNC] onUndo: inserting, arrayCount=\(self.photoAssets.count), cvCount=\(self.collectionView.numberOfItems(inSection: 0))"
            )
            self.deleteBinStore.addAssetId(asset.localIdentifier)
            self.photoAssets.append(asset)
            let insertIndexPath = IndexPath(item: self.photoAssets.count - 1, section: 0)

            self.collectionView.insertItems(at: [insertIndexPath])
            self.updateHeader()
            print(
                "[BIN SYNC] onUndo: done, arrayCount=\(self.photoAssets.count), cvCount=\(self.collectionView.numberOfItems(inSection: 0))"
            )
        }

        previewVC.onDeleteNow = { [weak self] in
            guard let self = self,
                let currentIndex = self.photoAssets.firstIndex(of: asset)
            else { return }
            let currentIndexPath = IndexPath(item: currentIndex, section: 0)

            previewVC.dismiss(animated: true) {
                self.performBatchDeletion(assets: [asset], indexPaths: [currentIndexPath])
            }
        }

        present(previewVC, animated: true)
    }

    // MARK: - Deletion
    @objc private func handleDeleteAll() {
        if isEditMode {
            let hasSelection = collectionView.indexPathsForSelectedItems?.isEmpty == false
            if hasSelection {
                handleDeleteSelected()
            }
            return
        }

        let assetsToDelete = photoAssets
        guard !assetsToDelete.isEmpty else { return }

        let alert = UIAlertController(
            title: Strings.deleteConfirmTitle(assets: assetsToDelete),
            message: Strings.deleteCannotUndo,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: Strings.cancel, style: .cancel))
        alert.addAction(
            UIAlertAction(title: Strings.delete, style: .destructive) { [weak self] _ in
                self?.performBatchDeletion(assets: assetsToDelete)
            })

        present(alert, animated: true)
    }

    private func performBatchDeletion(assets: [PHAsset]? = nil, indexPaths: [IndexPath]? = nil) {
        let assetsToDelete = assets ?? photoAssets
        let estimatedFreedBytes = calculateEstimatedSize(for: assetsToDelete)

        var assetSizes: [String: Int64] = [:]
        for asset in assetsToDelete {
            let resources = PHAssetResource.assetResources(for: asset)
            var total: Int64 = 0
            for resource in resources {
                if let size = resource.value(forKey: "fileSize") as? Int64 {
                    total += size
                }
            }
            assetSizes[asset.localIdentifier] = total
        }

        let loadingAlert = UIAlertController(title: Strings.deletingProgress, message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    self?.handleDeletionResult(
                        success: success, error: error, assets: assetsToDelete, indexPaths: indexPaths,
                        freedBytes: estimatedFreedBytes, assetSizes: assetSizes)
                }
            }
        }
    }

    private func handleDeletionResult(
        success: Bool, error: Error?, assets: [PHAsset], indexPaths: [IndexPath]?, freedBytes: Int64 = 0,
        assetSizes: [String: Int64] = [:]
    ) {
        if success {
            storageManager.invalidateAndRefresh()

            PhotoLibraryService.shared.invalidateMonthBucketsCache()
            ReminderDataCenter.shared.markCleanedNow(count: assets.count)

            if let indexPaths = indexPaths {
                for asset in assets {
                    deleteBinStore.removeAssetId(asset.localIdentifier)
                    if let index = photoAssets.firstIndex(of: asset) {
                        photoAssets.remove(at: index)
                    }
                }

                if photoAssets.isEmpty {
                    pendingEmptyKind = .freshEmpty(assets: assets, bytes: freedBytes)
                    updateUI()
                } else {
                    collectionView.deleteItems(at: indexPaths)
                    updateHeader()
                }

                if isEditMode {
                    setEditing(false, animated: true)
                }
            } else {
                if filterMonthKey != nil {
                    deleteBinStore.removeAssetIds(assets.map(\.localIdentifier))
                } else {
                    deleteBinStore.clearAll()
                }
                photoAssets = []
                pendingEmptyKind = .freshEmpty(assets: assets, bytes: freedBytes)
                updateUI()
            }
        } else {
            if let error = error as? NSError,
                error.domain == "PHPhotosErrorDomain",
                error.code == 3072
            {
                print("[BIN DELETE ERROR] User cancelled the deletion dialog.")
                return
            }

            if let error = error as? NSError,
                error.domain == "PHPhotosErrorDomain",
                error.code == 3301
            {
                print(
                    "[BIN DELETE ERROR] Deletion failed because the asset was not found. It may have already been deleted."
                )
            }

            let alert = UIAlertController(
                title: Strings.errorTitle,
                message: Strings.errorMessage,
                preferredStyle: .alert
            )
            print("[BIN DELETE ERROR] \(error?.localizedDescription ?? "Unknown error")")
            alert.addAction(UIAlertAction(title: Strings.ok, style: .default))

            present(alert, animated: true)
        }
    }
}

extension DeleteBinViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("[BIN DEBUG] numberOfItems: \(photoAssets.count)")
        return photoAssets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoThumbnailCell

        let asset = photoAssets[indexPath.item]

        cell.imageView.image = nil
        cell.representedAssetIdentifier = asset.localIdentifier
        print("[BIN DEBUG] cellForItem: index=\(indexPath.item), assetId=\(asset.localIdentifier)")

        ImageCacheService.shared.loadImage(
            for: asset,
            quality: .thumbnail,
            screenSize: CGSize(
                width: thumbnailSize.width / UIScreen.main.scale, height: thumbnailSize.height / UIScreen.main.scale),
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        ) { image, isInCloud, _ in
            guard cell.representedAssetIdentifier == asset.localIdentifier else { return }

            if let image = image {
                cell.imageView.image = image
            }

            cell.showICloudBadge(isInCloud)
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension DeleteBinViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if isEditMode {
            updateEditModeButtonsState()
            return
        }

        collectionView.deselectItem(at: indexPath, animated: true)

        let asset = photoAssets[indexPath.item]
        showPreview(for: asset)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if isEditMode {
            updateEditModeButtonsState()
        }
    }

    func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        return true
    }
}

@available(iOS 17.0, *)
#Preview("Default") {
    UINavigationController(rootViewController: DeleteBinViewController())
}

@available(iOS 17.0, *)
#Preview("Filtered by Month") {
    let vc = DeleteBinViewController()
    vc.filterMonthKey = "2025-01"
    vc.filterMonthTitle = "January 2025"
    return UINavigationController(rootViewController: vc)
}

@available(iOS 17.0, *)
#Preview("Empty State") {
    let vc = DeleteBinViewController()
    vc.configureForEmptyPreview()
    return UINavigationController(rootViewController: vc)
}

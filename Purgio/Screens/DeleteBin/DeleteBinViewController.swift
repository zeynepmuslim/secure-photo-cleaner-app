//
//  DeleteBinViewController.swift
//  Purgio
//
//  Created by ZeynepMüslim on 04.01.2026.
//

import MessageUI
import Photos
import SwiftUI
import UIKit

private enum Strings {
    static let navTitle = NSLocalizedString("deleteBin.navTitle", comment: "Delete bin navigation title")
    static let editMode = NSLocalizedString("deleteBin.editMode", comment: "Edit mode button")
    static let goToGeneralBin = NSLocalizedString("deleteBin.goToGeneralBin", comment: "Go to general bin button")
    static let remove = CommonStrings.remove
    static let cancel = CommonStrings.cancel
    static let delete = CommonStrings.delete
    static let ok = CommonStrings.ok
    static let preparingProgress = NSLocalizedString("deleteBin.preparingProgress", comment: "Preparing to delete progress label")
    static let deletingProgress = NSLocalizedString("deleteBin.deletingProgress", comment: "Deleting progress label")
    static let deleteCannotUndo = NSLocalizedString("deleteBin.deleteCannotUndo", comment: "Delete warning about Recently Deleted folder")
    static let yourDeleteBin = NSLocalizedString("deleteBin.yourDeleteBin", comment: "Your Delete Bin title")
    static let emptyHint = NSLocalizedString("deleteBin.emptyHint", comment: "Empty delete bin: how items get here and when they're deleted")
    static let youFreed = NSLocalizedString("deleteBin.youFreed", comment: "Label over the space freed by the last deletion")
    static let reviewAnother = NSLocalizedString("deleteBin.reviewAnother", comment: "Button after emptying the bin: review another month")
    static let reviewPhotos = NSLocalizedString("deleteBin.reviewPhotos", comment: "Button on the empty bin: go review photos")
    static let done = NSLocalizedString("deleteBin.done", comment: "Button after emptying the bin: leave the bin")
    static func reviewMonth(_ month: String) -> String {
        String(format: NSLocalizedString("deleteBin.reviewMonth", comment: "Button on the empty bin, e.g. 'Review August'"), month)
    }
    static func cleanedMessage(count: Int) -> String {
        String.localizedStringWithFormat(
            NSLocalizedString("deleteBin.cleanedMessage", comment: "After emptying the bin: how many items went to Recently Deleted"),
            count)
    }
    static func toReview(count: Int, isVideo: Bool) -> String {
        let format = isVideo
            ? NSLocalizedString("monthCell.videosToReview", comment: "Not-started month subtitle for videos")
            : NSLocalizedString("monthCell.photosToReview", comment: "Not-started month subtitle for photos")
        return String.localizedStringWithFormat(format, count)
    }
    static let successTitle = NSLocalizedString("deleteBin.successTitle", comment: "Success alert title")
    static let allDeletedMessage = NSLocalizedString("deleteBin.allDeletedMessage", comment: "All items deleted success message")
    static let errorTitle = NSLocalizedString("deleteBin.errorTitle", comment: "Error alert title")
    static let errorMessage = NSLocalizedString("deleteBin.errorMessage", comment: "Delete error message")
    static let tryAgain = NSLocalizedString("deleteBin.tryAgain", comment: "Try again button")
    static let tryInParts = NSLocalizedString("deleteBin.tryInParts", comment: "Retry deletion in smaller chunks")
    static let reportToDeveloper = NSLocalizedString("deleteBin.reportToDeveloper", comment: "Report error to developer button")
    static let reportSentTitle = NSLocalizedString("deleteBin.reportSentTitle", comment: "Error report sent confirmation title")
    static let reportSentMessage = NSLocalizedString("deleteBin.reportSentMessage", comment: "Error report sent confirmation message")
    static let mailNotConfiguredMessage = NSLocalizedString("deleteBin.mailNotConfiguredMessage", comment: "Mail app not configured message")

    private static func mediaDescription(for assets: [PHAsset]) -> String {
        let photoCount = assets.filter { $0.mediaType == .image }.count
        let videoCount = assets.filter { $0.mediaType == .video }.count

        switch (photoCount, videoCount) {
        case (let p, 0):
            return String.localizedStringWithFormat(NSLocalizedString("deleteBin.photoCount", comment: "Number of photos, e.g. '3 photos'"), p)
        case (0, let v):
            return String.localizedStringWithFormat(NSLocalizedString("deleteBin.videoCount", comment: "Number of videos, e.g. '2 videos'"), v)
        case (let p, let v):
            let photos = String.localizedStringWithFormat(NSLocalizedString("deleteBin.photoCount", comment: "Number of photos"), p)
            let videos = String.localizedStringWithFormat(NSLocalizedString("deleteBin.videoCount", comment: "Number of videos"), v)
            return String(format: NSLocalizedString("deleteBin.photoAndVideoCount", comment: "Combined photo and video count, e.g. '3 photos and 2 videos'"), photos, videos)
        }
    }

    static func removeConfirmTitle(assets: [PHAsset]) -> String {
        String(format: NSLocalizedString("deleteBin.removeConfirmTitle", comment: "Remove confirmation title, e.g. 'Remove 3 photos?'"), mediaDescription(for: assets))
    }
    static func removeConfirmMessage(assets: [PHAsset]) -> String {
        String.localizedStringWithFormat(NSLocalizedString("deleteBin.removeConfirmMessage", comment: "Remove confirmation message about restoring items"), assets.count)
    }
    static func deleteConfirmTitle(assets: [PHAsset]) -> String {
        String(format: NSLocalizedString("deleteBin.deleteConfirmTitle", comment: "Delete confirmation title, e.g. 'Delete 3 photos?'"), mediaDescription(for: assets))
    }
    static func photoCount(assets: [PHAsset]) -> String {
        mediaDescription(for: assets)
    }
    static func photoCountWithSize(assets: [PHAsset], size: String) -> String {
        String(format: NSLocalizedString("deleteBin.photoCountWithSize", comment: "Media count with size, e.g. '3 photos · ~2.5 GB'"), mediaDescription(for: assets), size)
    }
    static func monthBinTitle(monthTitle: String) -> String {
        String(format: NSLocalizedString("deleteBin.monthBinTitle", comment: "Month bin title, e.g. 'January 2025 Bin'"), monthTitle)
    }
    static func binCountTitle(count: Int) -> String {
        String(format: NSLocalizedString("deleteBin.binCountTitle", comment: "Bin count title, e.g. 'Bin · 5'"), count)
    }
    static let allCleanedTitle = NSLocalizedString("deleteBin.allCleanedTitle", comment: "All cleaned up title")
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
        label.layer.cornerCurve = .continuous
        label.layer.masksToBounds = true
        return label
    }()

    private let emptyStateView = EmptyStateView()

    private lazy var collectionView: UICollectionView = {
        let layout = FoldSplitFlowLayout()
        layout.minimumInteritemSpacing = GridGeometry.spacing
        layout.minimumLineSpacing = GridGeometry.spacing
        layout.sectionInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
        // Keep thumbnails out of side safe areas (vertical bars on iPhone Duo)
        layout.sectionInsetReference = .fromSafeArea
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.register(PhotoThumbnailCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collectionView.allowsMultipleSelection = false
        collectionView.contentInset = UIEdgeInsets(top: 50, left: 0, bottom: 100, right: 0)
        collectionView.scrollIndicatorInsets = collectionView.contentInset
        collectionView.useSoftTopEdgeEffect()
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
    private var lastGridGeometry: GridGeometry?
    private var skeletonLeadingConstraint: NSLayoutConstraint?
    private var skeletonTrailingConstraint: NSLayoutConstraint?
    private var headerCenterXConstraint: NSLayoutConstraint?
    private var editButtonsEdges: DuoEdgeConstraints?

    private enum EmptyKind {
        case defaultEmpty
        case freshEmpty(assets: [PHAsset], bytes: Int64)
    }
    private var pendingEmptyKind: EmptyKind = .defaultEmpty
    private var isShowingEmptyState = false

    /// The month the empty bin points back to.
    private struct ReviewTarget {
        let key: String
        let title: String
        let mediaType: PHAssetMediaType
    }

    private enum EmptyLayout {
        static let freedCardInsets = NSDirectionalEdgeInsets(
            top: GeneralConstants.EdgePadding.cardInner, leading: GeneralConstants.EdgePadding.cardInner,
            bottom: GeneralConstants.EdgePadding.cardInner, trailing: GeneralConstants.EdgePadding.cardInner)
        static let freedLabelSize: CGFloat = 13
        static let freedValueSize: CGFloat = 36
    }

    private var binController: FloatingBinButtonController? {
        tabBarController as? FloatingBinButtonController
    }

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
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitDisplayScale.self]) { (self: DeleteBinViewController, _) in
                self.calculateThumbnailSize()
            }
        }

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

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Width, rail and fold changes all change the geometry
        guard gridContentWidth > 0 else { return }
        let geometry = gridGeometry
        guard geometry != lastGridGeometry else { return }
        let isFirstLayout = lastGridGeometry == nil
        lastGridGeometry = geometry
        calculateThumbnailSize()
        collectionView.collectionViewLayout.invalidateLayout()
        if !isFirstLayout {
            // Reload visible thumbnails at the new size; keeps edit-mode selection
            collectionView.reconfigureItems(at: collectionView.indexPathsForVisibleItems)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let railEdge = DuoLayout.railEdge(tabBarController, in: view)
        editButtonsEdges?.update(railEdge: railEdge)
        emptyStateView.update(railEdge: railEdge)
        updateRailHeader()
        updateBinSpacerWidth(animated: false)
        headerLabel.layer.cornerRadius = headerLabel.bounds.height / 2
        headerLabel.layer.cornerCurve = .continuous
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.async { [weak self] in
            self?.updateBinSpacerWidth(animated: false)
        }
        // Every push and pop lets the bin button show again; the empty states have their own
        // bottom row where it would float
        if isShowingEmptyState {
            binController?.setBinButtonSuppressed(true)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isEditMode {
            setEditing(false, animated: false)
        }
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

        let headerCenterX = headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        headerCenterXConstraint = headerCenterX

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerCenterX,
            headerLabel.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -32),
            headerLabel.heightAnchor.constraint(equalToConstant: 32),

            emptyStateView.topAnchor.constraint(equalTo: view.topAnchor),
            emptyStateView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            emptyStateView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            emptyStateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            editButtonsStack.heightAnchor.constraint(equalToConstant: GeneralConstants.ButtonSize.large),
            removeSelectedButton.widthAnchor.constraint(equalTo: binSpacerView.widthAnchor)
        ])

        // Side and bottom edges follow Home's vertical-rail padding on iPhone Duo; with the
        // rail trailing, the leading edge matches the wide bin button's corner clearance
        let edges = DuoEdgeConstraints(
            item: editButtonsStack, in: view,
            standardLeading: GeneralConstants.EdgePadding.content,
            standardTrailing: GeneralConstants.EdgePadding.content,
            railTrailingFarLeading: DuoLayout.RailPadding.cornerClearance,
            standardBottom: GeneralConstants.Spacer.buttonBottom)
        editButtonsEdges = edges
        NSLayoutConstraint.activate(edges.initialConstraints)

        binSpacerWidthConstraint = binSpacerView.widthAnchor.constraint(equalToConstant: 0)
        binSpacerWidthConstraint?.priority = .defaultLow
        binSpacerWidthConstraint?.isActive = true

        collectionViewBottomConstraint = collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        collectionViewBottomConstraint.isActive = true
    }

    // Titled standard items (no custom "more" menu): the system picks the
    // representation and overflow on iPhone Duo; the ellipsis stays reserved for overflow.
    private func setupNavigationItems() {
        let editButton = UIBarButtonItem(
            image: UIImage(systemName: "pencil"),
            style: .plain,
            target: self,
            action: #selector(handleEditTap)
        )
        editButton.title = Strings.editMode

        guard filterMonthKey != nil else {
            navigationItem.rightBarButtonItems = [editButton]
            return
        }

        let generalBinButton = UIBarButtonItem(
            image: UIImage(systemName: "tray.full"),
            style: .plain,
            target: self,
            action: #selector(handleShowWholeBin)
        )
        generalBinButton.title = Strings.goToGeneralBin
        if #available(iOS 27.1, *) {
            editButton.visibilityPriority = .high
            generalBinButton.visibilityPriority = .low
        }
        navigationItem.rightBarButtonItems = [editButton, generalBinButton]
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
            navigationItem.rightBarButtonItems = [doneBarButtonItem]
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
    /// Grid width inside the side safe areas (matches `sectionInsetReference = .fromSafeArea`).
    private var gridContentWidth: CGFloat {
        let containerWidth = collectionView.bounds.width > 0 ? collectionView.bounds.width : view.bounds.width
        return containerWidth - view.safeAreaInsets.left - view.safeAreaInsets.right
    }

    /// Physical side section insets, lined up with the wide bin button. On a vertical rail
    /// (iPhone Duo only) the grid keeps 6pt from the rail. Across from a right-side rail the
    /// safe area is ~0, so it keeps clear of the device's rounded corner; across from a
    /// left-side rail (Split View, left half) it uses the bin button's standard padding.
    /// Elsewhere the original 2pt insets.
    private var gridSideInsets: (left: CGFloat, right: CGFloat) {
        switch DuoLayout.railSide(tabBarController, in: view) {
        case nil: return (2, 2)
        case .right: return (DuoLayout.RailPadding.cornerClearance, DuoLayout.RailPadding.nextToRail)
        case .left: return (DuoLayout.RailPadding.nextToRail, GeneralConstants.EdgePadding.medium)
        }
    }

    /// Vertical rail only: the header centers over the grid instead of the whole view
    /// (the side insets differ).
    private func updateRailHeader() {
        var headerOffset: CGFloat = 0
        if DuoLayout.isVerticalRail(tabBarController) {
            let geometry = gridGeometry
            let safeArea = view.safeAreaInsets
            headerOffset = ((safeArea.left + geometry.leftInset) - (safeArea.right + geometry.rightInset)) / 2
        }
        if let headerCenterX = headerCenterXConstraint, headerCenterX.constant != headerOffset {
            headerCenterX.constant = headerOffset
        }
    }

    /// 3 columns in compact width; an even count in regular width so the grid
    /// splits cleanly at the iPhone Duo fold (4, or 6 once cells would exceed 180pt).
    private func gridColumnCount(for width: CGFloat) -> CGFloat {
        guard traitCollection.horizontalSizeClass == .regular else { return 3 }
        return width / 4 > 180 ? 6 : 4
    }

    /// Item size and physical side insets of the grid.
    private struct GridGeometry: Equatable {
        static let spacing: CGFloat = 2

        var columns: Int
        var side: CGFloat
        var leftInset: CGFloat
        var rightInset: CGFloat
        /// Collection view x where the right half starts, when the grid splits at a fold.
        var splitX: CGFloat?
        /// Space added to the gap at `splitX` (0 while the device is fully open).
        var extraGap: CGFloat = 0
    }

    /// The regular grid inside `gridSideInsets`. With a vertical iPhone Duo fold across it
    /// (regular width, even column count), the two halves sit on either side of the fold
    /// line instead: the regular 2pt gap centered on it while fully open, the whole fold
    /// region while folded, so no thumbnail sits on the fold.
    private var gridGeometry: GridGeometry {
        let spacing = GridGeometry.spacing
        let base = gridSideInsets
        let width = gridContentWidth
        let columns = Int(gridColumnCount(for: width))
        let regularSide = floor((width - base.left - base.right - CGFloat(columns - 1) * spacing) / CGFloat(columns))
        let regular = GridGeometry(columns: columns, side: regularSide, leftInset: base.left, rightInset: base.right)

        guard columns.isMultiple(of: 2), traitCollection.horizontalSizeClass == .regular,
              let fold = FoldRegion.splittingFold(in: view), fold.height > fold.width else { return regular }

        let gap = FoldRegion.activeFold(in: view).map { max(spacing, $0.width) } ?? spacing
        let safeLeft = view.safeAreaInsets.left
        // Grid coordinates: from the safe area's left edge (`sectionInsetReference = .fromSafeArea`)
        let foldCenter = fold.midX - safeLeft
        let halfColumns = CGFloat(columns / 2)
        let halfRoom = min(foldCenter - gap / 2 - base.left, width - base.right - (foldCenter + gap / 2))
        let side = floor((halfRoom - (halfColumns - 1) * spacing) / halfColumns)
        guard side > 0 else { return regular }

        let halfWidth = halfColumns * side + (halfColumns - 1) * spacing
        let leftInset = foldCenter - gap / 2 - halfWidth
        let extraGap = gap - spacing
        // The flow layout sees the regular spacing everywhere; the right inset leaves room
        // for the right half's shift
        let rightInset = width - leftInset - CGFloat(columns) * side - CGFloat(columns - 1) * spacing - extraGap
        return GridGeometry(
            columns: columns, side: side, leftInset: leftInset, rightInset: rightInset,
            splitX: safeLeft + leftInset + halfWidth + spacing / 2, extraGap: extraGap)
    }

    private func calculateThumbnailSize() {
        let geometry = gridGeometry
        skeletonGridView?.columns = geometry.columns
        let scale = traitCollection.displayScale
        thumbnailSize = CGSize(width: geometry.side * scale, height: geometry.side * scale)

        if let layout = collectionView.collectionViewLayout as? FoldSplitFlowLayout {
            layout.itemSize = CGSize(width: geometry.side, height: geometry.side)
            layout.sectionInset.left = geometry.leftInset
            layout.sectionInset.right = geometry.rightInset
            layout.splitX = geometry.splitX
            layout.extraGap = geometry.extraGap
        }
        skeletonLeadingConstraint?.constant = geometry.leftInset
        skeletonTrailingConstraint?.constant = -geometry.rightInset
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
            let geometry = gridGeometry
            let skeleton = SkeletonGridView(columns: geometry.columns)
            skeleton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(skeleton)
            self.skeletonGridView = skeleton

            // Same grid as the collection view: 50pt top content inset plus the section
            // insets (wider leading on a vertical rail), inside the side safe areas (`sectionInsetReference = .fromSafeArea`)
            let leading = skeleton.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: geometry.leftInset)
            let trailing = skeleton.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -geometry.rightInset)
            skeletonLeadingConstraint = leading
            skeletonTrailingConstraint = trailing
            NSLayoutConstraint.activate([
                skeleton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
                leading,
                trailing,
                skeleton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
            ])

            skeleton.startAnimating()
        }
    }

    private func hideLoadingState() {
        skeletonGridView?.fadeOut { [weak self] in
            self?.skeletonGridView = nil
            self?.skeletonLeadingConstraint = nil
            self?.skeletonTrailingConstraint = nil
        }
    }

    private func updateUI() {
        // Reload in both branches: a hidden grid that kept its old items crashed on the next
        // size change, when viewWillLayoutSubviews reconfigured them past the emptied array
        collectionView.reloadData()
        if photoAssets.isEmpty {
            showEmptyState()
        } else {
            hideEmptyState()
            updateHeader()
        }
    }

    private func updateHeader() {
        let currentAssets = photoAssets

        headerLabel.text = Strings.photoCount(assets: currentAssets)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            var estimatedSize: Int64 = 0
            for asset in currentAssets {
                for resource in PHAssetResource.assetResources(for: asset) {
                    if let size = resource.value(forKey: "fileSize") as? Int64 { estimatedSize += size }
                }
            }
            let sizeString = estimatedSize.formattedBytes()

            DispatchQueue.main.async {
                if self.photoAssets.count == currentAssets.count {
                    self.headerLabel.text = Strings.photoCountWithSize(assets: currentAssets, size: sizeString)
                }
            }
        }
    }

    // MARK: - Empty State

    /// Board "Empty & finished states · A + B": an empty bin says what it's for and points at
    /// a month to review; a bin that was just emptied shows the stamp and the space freed.
    private func showEmptyState() {
        switch pendingEmptyKind {
        case .defaultEmpty:
            let target = reviewTarget()
            emptyStateView.configure(
                hero: .symbol("trash"),
                title: filterMonthTitle.map { Strings.monthBinTitle(monthTitle: $0) } ?? Strings.yourDeleteBin,
                message: Strings.emptyHint,
                accessory: target.flatMap { makeMonthCard(for: $0) },
                actionTitle: target.map { Strings.reviewMonth(shortName(of: $0)) } ?? Strings.reviewPhotos,
                actionIcon: "play.fill",
                onAction: { [weak self] in
                    if let target {
                        self?.openHub(for: target)
                    } else {
                        self?.openMonthsList()
                    }
                })
        case .freshEmpty(let deletedAssets, let bytes):
            emptyStateView.configure(
                hero: .stamp,
                title: Strings.allCleanedTitle,
                message: Strings.cleanedMessage(count: deletedAssets.count),
                accessory: bytes > 0 ? makeFreedCard(bytes: bytes) : nil,
                actionTitle: Strings.reviewAnother,
                actionIcon: "play.fill",
                onAction: { [weak self] in self?.openMonthsList() },
                secondaryTitle: Strings.done,
                onSecondary: { [weak self] in
                    self?.navigationController?.popViewController(animated: true)
                })
        }
        isShowingEmptyState = true
        // The states' cards are white; they sit on the grouped background
        view.backgroundColor = .mainBackground
        emptyStateView.isHidden = false
        emptyStateView.update(railEdge: DuoLayout.railEdge(tabBarController, in: view))
        emptyStateView.show(animated: true)
        collectionView.isHidden = true
        headerLabel.isHidden = true
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
        binController?.setBinButtonSuppressed(true)
    }

    /// The bin's own month while it has work left (photos first), else the newest month in
    /// progress, else none.
    private func reviewTarget() -> ReviewTarget? {
        let progressStore = ReviewProgressStore.shared
        if let key = filterMonthKey, let title = filterMonthTitle {
            for mediaType in [PHAssetMediaType.image, .video] {
                // Started or not, as long as its total is known and not all of it is reviewed
                let hasTotal = progressStore.getProgress(forMonthKey: key, mediaType: mediaType).originalTotalCount > 0
                if hasTotal, !progressStore.isComplete(monthKey: key, mediaType: mediaType) {
                    return ReviewTarget(key: key, title: title, mediaType: mediaType)
                }
            }
        }
        // A record can outlive its month (the library changed since); when the month buckets
        // are known, the month has to be one of them
        let newest = DashboardCardManager.shared.getInProgressMonths().first { info in
            guard let buckets = photoLibraryService.getCachedMonthBuckets(mediaType: info.mediaType) else {
                return true
            }
            return buckets.contains { $0.key == info.monthKey }
        }
        guard let newest else { return nil }
        return ReviewTarget(
            key: newest.monthKey,
            title: DateFormatterManager.shared.displayMonth(fromMonthKey: newest.monthKey),
            mediaType: newest.mediaType)
    }

    /// "August" for the button; the card shows the full title.
    private func shortName(of target: ReviewTarget) -> String {
        DateFormatterManager.shared.monthName(fromMonthKey: target.key) ?? target.title
    }

    /// The month's row as on the months list, in a tappable card.
    private func makeMonthCard(for target: ReviewTarget) -> UIView? {
        let progress = ReviewProgressStore.shared.getProgress(forMonthKey: target.key, mediaType: target.mediaType)
        guard progress.originalTotalCount > 0 else { return nil }

        let card = MonthLinkCardView()
        card.rowView.configure(
            title: target.title,
            deleted: progress.deletedCount,
            kept: progress.keptCount,
            stored: progress.storedCount,
            total: progress.originalTotalCount,
            reviewed: progress.reviewedCount,
            notStartedSubtitle: Strings.toReview(
                count: progress.originalTotalCount, isVideo: target.mediaType == .video))
        card.accessibilityLabel = card.rowView.accessibilitySummary
        card.onTap = { [weak self] in self?.openHub(for: target) }
        return card
    }

    private func makeFreedCard(bytes: Int64) -> UIView {
        let card = UIView()
        card.backgroundColor = .cardBackground
        card.layer.cornerRadius = GeneralConstants.CornerRadius.card
        card.layer.cornerCurve = .continuous

        let label = UILabel()
        label.font = .systemFont(ofSize: EmptyLayout.freedLabelSize, weight: .regular)
        label.textColor = .textSecondary
        label.text = Strings.youFreed

        let valueLabel = UILabel()
        valueLabel.font = .monospacedDigitSystemFont(ofSize: EmptyLayout.freedValueSize, weight: .heavy)
        valueLabel.textColor = .textPrimary
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.6
        valueLabel.text = bytes.formattedBytes()

        let stack = UIStackView(arrangedSubviews: [label, valueLabel])
        stack.axis = .vertical
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        let insets = EmptyLayout.freedCardInsets
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: insets.top),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: insets.leading),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -insets.trailing),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -insets.bottom)
        ])

        card.isAccessibilityElement = true
        card.accessibilityLabel = [Strings.youFreed, valueLabel.text].compactMap { $0 }.joined(separator: ", ")
        return card
    }

    /// The month's hub on its own tab (Photos 1, Videos 2), with the months list under it.
    private func openHub(for target: ReviewTarget) {
        let index = target.mediaType == .video ? 2 : 1
        guard let tabBarController,
              let destination = tabBarController.viewControllers?[index] as? UINavigationController,
              !destination.viewControllers.isEmpty else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        let hub = MonthFilterCardsViewController(
            monthTitle: target.title, monthKey: target.key, mediaType: target.mediaType)

        if destination === navigationController {
            destination.popToRootViewController(animated: false)
            destination.pushViewController(hub, animated: true)
        } else {
            // Leave this tab's stack clean, then push the hub on the month's tab (as Home's navigateOnTab)
            navigationController?.popToRootViewController(animated: false)
            binController?.setBinButtonSuppressed(false)
            tabBarController.selectedIndex = index
            destination.popToRootViewController(animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                destination.pushViewController(hub, animated: true)
            }
        }
    }

    /// The Photos tab's months list.
    private func openMonthsList() {
        guard let tabBarController,
              let destination = tabBarController.viewControllers?[1] as? UINavigationController else { return }
        HapticFeedbackManager.shared.impact(intensity: .medium)
        if destination === navigationController {
            destination.popToRootViewController(animated: true)
        } else {
            navigationController?.popToRootViewController(animated: false)
            binController?.setBinButtonSuppressed(false)
            tabBarController.selectedIndex = 1
            destination.popToRootViewController(animated: false)
        }
    }

    private func showErrorAlert() {
        let alert = UIAlertController(
            title: Strings.errorTitle,
            message: Strings.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        present(alert, animated: true)
    }

    private func showDeletionFailedAlert(
        assets: [PHAsset], indexPaths: [IndexPath]?,
        totalBytes: Int64, assetSizes: [String: Int64]
    ) {
        let alert = UIAlertController(
            title: Strings.errorTitle,
            message: Strings.errorMessage,
            preferredStyle: .alert
        )

        if assets.count > 500 {
            alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
            alert.addAction(UIAlertAction(title: Strings.tryInParts, style: .default) { [weak self] _ in
                self?.performChunkedDeletion(assets: assets, indexPaths: indexPaths, totalBytes: totalBytes, assetSizes: assetSizes)
            })
        } else {
            alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        }

        present(alert, animated: true)
    }

    private func performChunkedDeletion(
        assets: [PHAsset], indexPaths: [IndexPath]?,
        totalBytes: Int64, assetSizes: [String: Int64]
    ) {
        let loadingAlert = UIAlertController(title: Strings.deletingProgress, message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)

        let chunkSize = 500
        let chunks = stride(from: 0, to: assets.count, by: chunkSize).map {
            Array(assets[$0 ..< min($0 + chunkSize, assets.count)])
        }

        deleteNextChunk(
            chunks: chunks, index: 0, totalAssets: assets,
            indexPaths: indexPaths, totalBytes: totalBytes, assetSizes: assetSizes,
            loadingAlert: loadingAlert
        )
    }

    private func deleteNextChunk(
        chunks: [[PHAsset]], index: Int, totalAssets: [PHAsset],
        indexPaths: [IndexPath]?, totalBytes: Int64, assetSizes: [String: Int64],
        loadingAlert: UIAlertController
    ) {
        guard index < chunks.count else {
            loadingAlert.dismiss(animated: true) { [weak self] in
                self?.handleDeletionResult(
                    success: true, error: nil, assets: totalAssets,
                    indexPaths: indexPaths, freedBytes: totalBytes, assetSizes: assetSizes)
            }
            return
        }

        if chunks.count > 1 {
            let processed = min(index * 500 + chunks[index].count, totalAssets.count)
            loadingAlert.message = "\(processed) / \(totalAssets.count)"
        }

        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(chunks[index] as NSArray)
        }) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.deleteNextChunk(
                        chunks: chunks, index: index + 1, totalAssets: totalAssets,
                        indexPaths: indexPaths, totalBytes: totalBytes, assetSizes: assetSizes,
                        loadingAlert: loadingAlert
                    )
                } else {
                    loadingAlert.dismiss(animated: true) { [weak self] in
                        self?.showChunkedDeletionFailedAlert(
                            error: error, assets: totalAssets,
                            indexPaths: indexPaths, totalBytes: totalBytes,
                            assetSizes: assetSizes)
                    }
                }
            }
        }
    }

    private func showChunkedDeletionFailedAlert(
        error: Error?,
        assets: [PHAsset],
        indexPaths: [IndexPath]?,
        totalBytes: Int64,
        assetSizes: [String: Int64]
    ) {
        print("[CHUNK DELETE ERROR] code=\((error as? NSError)?.code ?? -1) \(error?.localizedDescription ?? "Unknown error")")

        let alert = UIAlertController(
            title: Strings.errorTitle,
            message: Strings.errorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
        alert.addAction(UIAlertAction(title: Strings.tryAgain, style: .default) { [weak self] _ in
            self?.performChunkedDeletion(assets: assets, indexPaths: indexPaths, totalBytes: totalBytes, assetSizes: assetSizes)
        })
        alert.addAction(UIAlertAction(title: Strings.reportToDeveloper, style: .default) { [weak self] _ in
            self?.sendErrorReport(error: error)
        })
        present(alert, animated: true)
    }

    private func sendErrorReport(error: Error?) {
        guard MFMailComposeViewController.canSendMail() else {
            let alert = UIAlertController(
                title: Strings.errorTitle,
                message: Strings.mailNotConfiguredMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
            present(alert, animated: true)
            return
        }

        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = self
        composer.setToRecipients(["zeynep.muslim@icloud.com"])
        composer.setSubject("Purgio Deletion Error Report")
        composer.setMessageBody(buildErrorReportBody(error: error), isHTML: false)
        present(composer, animated: true)
    }

    private func buildErrorReportBody(error: Error?) -> String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        let nsError = error as? NSError

        return """
        Purgio Error Report
        ===================

        Error Code  : \(nsError?.code.description ?? "-")
        Error Domain: \(nsError?.domain ?? "-")
        Description : \(error?.localizedDescription ?? "-")

        Device      : \(device.model)
        iOS Version : \(device.systemVersion)
        App Version : \(appVersion) (\(buildNumber))
        Date        : \(Date())
        """
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
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
        guard isShowingEmptyState else { return }
        isShowingEmptyState = false
        view.backgroundColor = .systemBackground
        binController?.setBinButtonSuppressed(false)
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
        guard !assetsToDelete.isEmpty else { return }

        let loadingAlert = UIAlertController(title: Strings.preparingProgress, message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Single pass off the main thread
            var assetSizes: [String: Int64] = [:]
            var totalBytes: Int64 = 0
            for asset in assetsToDelete {
                var assetTotal: Int64 = 0
                for resource in PHAssetResource.assetResources(for: asset) {
                    if let size = resource.value(forKey: "fileSize") as? Int64 { assetTotal += size }
                }
                assetSizes[asset.localIdentifier] = assetTotal
                totalBytes += assetTotal
            }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                loadingAlert.title = Strings.deletingProgress

                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
                }) { [weak self] success, error in
                    DispatchQueue.main.async {
                        loadingAlert.dismiss(animated: true) {
                            self?.handleDeletionResult(
                                success: success, error: error, assets: assetsToDelete,
                                indexPaths: indexPaths, freedBytes: totalBytes, assetSizes: assetSizes)
                        }
                    }
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

            print("[BIN DELETE ERROR] code=\((error as? NSError)?.code ?? -1) \(error?.localizedDescription ?? "Unknown error")")
            showDeletionFailedAlert(assets: assets, indexPaths: indexPaths, totalBytes: freedBytes, assetSizes: assetSizes)
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
                width: thumbnailSize.width / traitCollection.displayScale,
                height: thumbnailSize.height / traitCollection.displayScale),
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
            traitCollection: traitCollection
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

extension DeleteBinViewController: MFMailComposeViewControllerDelegate {
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true) { [weak self] in
            guard result == .sent else { return }
            let alert = UIAlertController(
                title: Strings.reportSentTitle,
                message: Strings.reportSentMessage,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: Strings.ok, style: .default))
            self?.present(alert, animated: true)
        }
    }
}

#if DEBUG
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
#endif

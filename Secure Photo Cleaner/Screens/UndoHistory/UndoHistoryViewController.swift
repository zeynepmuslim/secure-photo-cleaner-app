//
//  UndoHistoryViewController.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Photos
import SwiftUI
import UIKit

protocol UndoHistoryDelegate: AnyObject {
    func didPerformAction(_ actionType: UndoAction.ActionType, on action: UndoAction)
    func didUndoAll(_ actions: [UndoAction])
    func didUndoActions(_ actions: [UndoAction])
}

final class UndoHistoryViewController: UIViewController {

    weak var delegate: UndoHistoryDelegate?
    private let historyManager = UndoHistoryManager.shared
    private let imageManager = PHCachingImageManager()
    private var thumbnailSize: CGSize = .zero

    private var thumbnailCache: [String: UIImage] = [:]

    private var isEditMode = false

    private var keepButton: DynamicGlassButton!
    private var deleteButton: DynamicGlassButton!
    private var storeButton: DynamicGlassButton!
    private var undoButton: DynamicGlassButton!

    private func setupSelectionToolbar() {
        view.addSubview(selectionToolbar)
        selectionToolbar.isHidden = true

        func createButton(title: String, systemImage: String, color: UIColor, action: Selector) -> DynamicGlassButton {
            let button = DynamicGlassButton()
            button.configure(
                title: title,
                systemImage: systemImage,
                style: .prominent,
                backgroundColor: color,
                fontSize: 13,
                iconSize: 11,
                contentInsets: NSDirectionalEdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)   // Tighter insets
            )
            button.addTarget(self, action: action, for: .touchUpInside)
            return button
        }

        keepButton = createButton(
            title: NSLocalizedString("undoHistory.keep", comment: "Keep button"), systemImage: "checkmark.circle.fill", color: .systemGreen,
            action: #selector(handleKeepSelected))
        deleteButton = createButton(
            title: NSLocalizedString("undoHistory.delete", comment: "Delete button"), systemImage: "trash.fill", color: .systemRed, action: #selector(handleDeleteSelected))
        storeButton = createButton(
            title: NSLocalizedString("undoHistory.store", comment: "Store button"), systemImage: "archivebox.fill", color: .systemYellow, action: #selector(handleStoreSelected))
        undoButton = createButton(
            title: NSLocalizedString("undoHistory.undo", comment: "Undo button"), systemImage: "arrow.uturn.backward", color: .systemGray,
            action: #selector(handleUndoSelected))

        selectionToolbar.addArrangedSubview(keepButton)
        selectionToolbar.addArrangedSubview(deleteButton)
        selectionToolbar.addArrangedSubview(storeButton)
        selectionToolbar.addArrangedSubview(undoButton)
    }

    private var actions: [UndoAction] {
        Array(historyManager.getCurrentSessionActions().reversed())
    }

    private let headerView = UIView()
    private let titleLabel = UILabel()
    private let statsLabel = UILabel()

    private let tableView: UITableView = {
        let tabel = UITableView(frame: .zero, style: .insetGrouped)
        tabel.translatesAutoresizingMaskIntoConstraints = false
        tabel.register(UndoHistoryCell.self, forCellReuseIdentifier: "UndoHistoryCell")
        tabel.separatorStyle = .singleLine
        tabel.rowHeight = 76
        tabel.allowsMultipleSelectionDuringEditing = true
        return tabel
    }()

    private let selectionToolbar: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.alignment = .center
//        stack.backgroundColor = .red
        stack.distribution = .fillEqually
        stack.spacing = 8
        return stack
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        calculateThumbnailSize()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHistoryDidChange),
            name: .undoHistoryDidChange,
            object: nil
        )

        historyManager.removeActionsForDeletedAssets()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleHistoryDidChange() {
        tableView.reloadData()
        updateStatsLabel()

        if historyManager.undoCount == 0 {
            dismiss(animated: true)
        }
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)

        titleLabel.text = "Review History"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        updateStatsLabel()
        statsLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statsLabel.textColor = .secondaryLabel
        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(statsLabel)

        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(handleDone)
        )

        setupOptionsMenu()
        setupSelectionToolbar()
        view.bringSubviewToFront(selectionToolbar)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 70),

            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            statsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            statsLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),

            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            selectionToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectionToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectionToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            selectionToolbar.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func calculateThumbnailSize() {
        let scale = UIScreen.main.scale
        let size: CGFloat = 60
        thumbnailSize = CGSize(width: size * scale, height: size * scale)
    }

    private func updateStatsLabel() {
        let stats = historyManager.getStatistics()
        let totalCount = historyManager.undoCount

        let attributedString = NSMutableAttributedString()

        let countText = NSAttributedString(
            string: String.localizedStringWithFormat(NSLocalizedString("undoHistory.itemCount", comment: "Item count with bullet, e.g. '5 items  •  '"), totalCount),
            attributes: [.foregroundColor: UIColor.secondaryLabel]
        )
        attributedString.append(countText)

        if let trashImage = UIImage(systemName: "trash.fill")?.withTintColor(.systemRed) {
            let trashAttachment = NSTextAttachment()
            trashAttachment.image = trashImage
            trashAttachment.bounds = CGRect(x: 0, y: -2, width: 15, height: 15)
            attributedString.append(NSAttributedString(attachment: trashAttachment))
        }
        attributedString.append(
            NSAttributedString(string: " \(stats.deleted)  ", attributes: [.foregroundColor: UIColor.secondaryLabel]))

        if let checkImage = UIImage(systemName: "checkmark.circle.fill")?.withTintColor(.systemGreen) {
            let checkAttachment = NSTextAttachment()
            checkAttachment.image = checkImage
            checkAttachment.bounds = CGRect(x: 0, y: -2, width: 15, height: 15)
            attributedString.append(NSAttributedString(attachment: checkAttachment))
        }
        attributedString.append(
            NSAttributedString(string: " \(stats.kept)  ", attributes: [.foregroundColor: UIColor.secondaryLabel]))

        if let uploadImage = UIImage(systemName: "archivebox.fill")?.withTintColor(.systemYellow) {
            let uploadAttachment = NSTextAttachment()
            uploadAttachment.image = uploadImage
            uploadAttachment.bounds = CGRect(x: 0, y: -2, width: 16, height: 14)
            attributedString.append(NSAttributedString(attachment: uploadAttachment))
        }
        attributedString.append(
            NSAttributedString(string: " \(stats.stored)", attributes: [.foregroundColor: UIColor.secondaryLabel]))

        statsLabel.attributedText = attributedString
    }

    private func setupOptionsMenu() {
        let selectAction = UIAction(
            title: NSLocalizedString("undoHistory.selectMultiple", comment: "Select multiple button"),
            image: UIImage(systemName: "checkmark.circle")
        ) { [weak self] _ in
            self?.toggleEditMode()
        }

        let undoAllAction = UIAction(
            title: NSLocalizedString("undoHistory.undoAllTitle", comment: "Undo all button"),
            image: UIImage(systemName: "arrow.uturn.backward.circle"),
            attributes: .destructive
        ) { [weak self] _ in
            self?.handleUndoAll()
        }

        let menu = UIMenu(title: "", children: [selectAction, undoAllAction])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            menu: menu
        )
    }

    private func updateToolbarButtonsState() {
        let hasSelection = tableView.indexPathsForSelectedRows?.isEmpty == false
        keepButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection

        storeButton.isEnabled = hasSelection
        undoButton.isEnabled = hasSelection
    }

    private func toggleEditMode() {
        isEditMode.toggle()
        tableView.setEditing(isEditMode, animated: true)
        selectionToolbar.isHidden = !isEditMode

        // Update content inset so rows aren't hidden behind toolbar
        let bottomInset: CGFloat = isEditMode ? 58 : 0
        tableView.contentInset.bottom = bottomInset
        tableView.verticalScrollIndicatorInsets.bottom = bottomInset

        UIView.animate(withDuration: 0.25) {
            self.view.layoutIfNeeded()
        }

        if isEditMode {
            updateToolbarButtonsState()
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(handleEditDone)
            )
        } else {
            setupOptionsMenu()
        }
    }

    @objc private func handleEditDone() {
        toggleEditMode()
    }

    private func handleUndoAll() {
        let alert = UIAlertController(
            title: NSLocalizedString("undoHistory.undoAllTitle", comment: "Undo all alert title"),
            message: NSLocalizedString("undoHistory.undoAllMessage", comment: "Undo all confirmation message"),
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: CommonStrings.cancel, style: .cancel))
        alert.addAction(
            UIAlertAction(title: NSLocalizedString("undoHistory.undoAllTitle", comment: "Undo all button"), style: .destructive) { [weak self] _ in
                self?.performUndoAll()
            })

        present(alert, animated: true)
    }

    private func performUndoAll() {
        let actions = historyManager.popAll()

        delegate?.didUndoAll(actions)

        tableView.reloadData()
        updateStatsLabel()

        dismiss(animated: true)
    }

    @objc private func handleKeepSelected() {
        applyActionToSelectedRows(.keep)
    }

    @objc private func handleDeleteSelected() {
        applyActionToSelectedRows(.delete)
    }

    @objc private func handleStoreSelected() {
        applyActionToSelectedRows(.store)
    }

    @objc private func handleUndoSelected() {
        guard let selectedRows = tableView.indexPathsForSelectedRows, !selectedRows.isEmpty else { return }

        let selectedActions = selectedRows.map { actions[$0.row] }
        let selectedIDs = Set(selectedActions.map { $0.id })

        let undoneActions = historyManager.removeActions(withIDs: selectedIDs)

        delegate?.didUndoActions(undoneActions)

        toggleEditMode()
        tableView.reloadData()
        updateStatsLabel()

        if historyManager.undoCount == 0 {
            dismiss(animated: true)
        }
    }

    private func applyActionToSelectedRows(_ actionType: UndoAction.ActionType) {
        guard let selectedRows = tableView.indexPathsForSelectedRows, !selectedRows.isEmpty else { return }

        // Sort in reverse order to handle index changes
        let sortedRows = selectedRows.sorted { $0.row > $1.row }

        for indexPath in sortedRows {
            handleAction(actionType, forIndexPath: indexPath)
        }

        toggleEditMode()
    }

    // MARK: - Actions
    @objc private func handleDone() {
        dismiss(animated: true)
    }

    private func handleAction(_ actionType: UndoAction.ActionType, forIndexPath indexPath: IndexPath) {
        let action = actions[indexPath.row]

        _ = historyManager.updateAction(at: indexPath.row, newActionType: actionType)
        delegate?.didPerformAction(actionType, on: action)
        tableView.reloadRows(at: [indexPath], with: .automatic)
        updateStatsLabel()
    }
}

// MARK: - UITableViewDataSource
extension UndoHistoryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        actions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UndoHistoryCell", for: indexPath) as! UndoHistoryCell
        let action = actions[indexPath.row]

        if let cachedImage = thumbnailCache[action.assetLocalIdentifier] {
            cell.configure(with: action, thumbnail: cachedImage)
            return cell
        }

        let fetchOptions = PHFetchOptions()
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [action.assetLocalIdentifier], options: fetchOptions)

        if let asset = result.firstObject {
            ImageCacheService.shared.loadImage(
                for: asset,
                quality: .thumbnail,
                screenSize: CGSize(width: 60, height: 60),
                allowNetworkAccess: SettingsStore.shared.allowInternetAccess
            ) { [weak self] image, _, _ in
                if let image = image {
                    self?.thumbnailCache[action.assetLocalIdentifier] = image
                }
                cell.configure(with: action, thumbnail: image)
            }
        } else {
            cell.configureAsDeleted(with: action)   // Asset was permanently deleted - show placeholder
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension UndoHistoryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateToolbarButtonsState()
            return
        }

        tableView.deselectRow(at: indexPath, animated: true)

        let action = actions[indexPath.row]

        //  better quality for sheet
        let fetchOptions = PHFetchOptions()
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [action.assetLocalIdentifier], options: fetchOptions)

        guard let asset = result.firstObject else { return }

        ImageCacheService.shared.loadImage(
            for: asset,
            quality: .full,
            screenSize: CGSize(width: 1000, height: 1000),
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        ) { [weak self] image, _, _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let bottomSheet = HistoryDetailBottomSheet(action: action, image: image, mediaType: asset.mediaType)

                bottomSheet.onKeepTapped = { [weak self] in
                    self?.handleAction(.keep, forIndexPath: indexPath)
                }

                bottomSheet.onDeleteTapped = { [weak self] in
                    self?.handleAction(.delete, forIndexPath: indexPath)
                }

                bottomSheet.onStoreTapped = { [weak self] in
                    self?.handleAction(.store, forIndexPath: indexPath)
                }

                self.present(bottomSheet, animated: true)
            }
        }
    }

    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            updateToolbarButtonsState()
        }
    }
}

@available(iOS 17.0, *)
#Preview {
    UINavigationController(rootViewController: UndoHistoryViewController())
}

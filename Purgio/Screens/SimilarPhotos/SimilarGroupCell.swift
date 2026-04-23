//
//  SimilarGroupCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos
import UIKit

private enum Strings {
    static let undoAction = NSLocalizedString("similarGroup.undoAction", comment: "Undo action button")
    static let confirm = NSLocalizedString("similarGroup.confirm", comment: "Confirm button")
    static let keep = NSLocalizedString("similarGroup.keep", comment: "Keep state label")
    static let delete = NSLocalizedString("similarGroup.delete", comment: "Delete state label")
    static let store = NSLocalizedString("similarGroup.store", comment: "Store state label")
    static func setTitle(index: Int) -> String {
        String(format: NSLocalizedString("similarGroup.setTitle", comment: "Set title with number, e.g. 'Set #1'"), index + 1)
    }
}

protocol SimilarGroupCellDelegate: AnyObject {
    func didTapConfirm(cell: SimilarGroupCell)
    func didTapUndo(cell: SimilarGroupCell)
    func didInteractWithCell(_ cell: SimilarGroupCell)
    func didChangeAssetStates(_ cell: SimilarGroupCell, states: [String: SimilarGroupCell.PhotoState])
}

class SimilarGroupCell: UITableViewCell {
    enum PhotoState {
        case keep
        case delete
        case store

        var borderColor: UIColor {
            switch self {
            case .keep: return ThemeManager.Colors.statusGreen
            case .delete: return ThemeManager.Colors.statusRed
            case .store: return ThemeManager.Colors.statusYellow
            }
        }

        var overlayIcon: String {
            switch self {
            case .keep: return "checkmark.circle.fill"
            case .delete: return "xmark.circle.fill"
            case .store: return "archivebox.fill"
            }
        }

        var overlayColor: UIColor {
            switch self {
            case .keep: return ThemeManager.Colors.statusGreen.withAlphaComponent(0.9)
            case .delete: return ThemeManager.Colors.statusRed.withAlphaComponent(0.9)
            case .store: return ThemeManager.Colors.statusYellow.withAlphaComponent(0.9)
            }
        }

        var tagLabel: String {
            switch self {
            case .keep: return Strings.keep
            case .delete: return Strings.delete
            case .store: return Strings.store
            }
        }

        var tagIcon: String {
            switch self {
            case .keep: return "checkmark"
            case .delete: return "trash"
            case .store: return "archivebox.fill"
            }
        }

        var tagIconSize: CGFloat {
            switch self {
            case .keep: return 15
            case .delete: return 13
            case .store: return 14
            }
        }
    }

    static let reuseIdentifier = "SimilarGroupCell"
    weak var delegate: SimilarGroupCellDelegate?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .cardBackground
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = ThemeManager.Fonts.titleFont(size: 17, weight: .semibold)
        label.textColor = .textPrimary
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(PhotoGridCell.self, forCellWithReuseIdentifier: PhotoGridCell.reuseIdentifier)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()

    private lazy var confirmButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.configure(
            title: Strings.confirm,
            style: .prominent,
            backgroundColor: .systemGray3,
            fontSize: 14,
            fontWeight: .semibold,
            contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleConfirm), for: .touchUpInside)
        return button
    }()

    private lazy var storeButton: DynamicGlassButton = {
        let button = DynamicGlassButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(handleStoreToggle), for: .touchUpInside)
        return button
    }()

    private let buttonRow: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var undoButton: UIButton = {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = Strings.undoAction
        config.image = UIImage(systemName: "arrow.uturn.backward.circle.fill")
        config.imagePadding = 8
        config.baseBackgroundColor = .secondarySystemFill
        config.baseForegroundColor = .label
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)

        button.configuration = config
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        button.addTarget(self, action: #selector(handleUndo), for: .touchUpInside)
        return button
    }()

    private var group: SimilarAssetGroup?
    private var assetStates: [String: PhotoState] = [:]
    private var isStoreMode: Bool = false

    // Preview overlay
    private var previewOverlay: UIView?
    private var previewImageView: UIImageView?
    private var previewRequestID: PHImageRequestID?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraint()
        setupLongPressGesture()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        configureStoreButtonNormal()

        buttonRow.addArrangedSubview(confirmButton)

        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(collectionView)
        containerView.addSubview(storeButton)
        containerView.addSubview(buttonRow)
        containerView.addSubview(undoButton)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: storeButton.leadingAnchor, constant: -8),

            storeButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            storeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            storeButton.widthAnchor.constraint(equalToConstant: 32),
            storeButton.heightAnchor.constraint(equalToConstant: 32),

            collectionView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 110),

            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.widthAnchor.constraint(equalTo: containerView.widthAnchor, constant: -24),

            buttonRow.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 8),
            buttonRow.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            buttonRow.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            buttonRow.heightAnchor.constraint(equalToConstant: 44),

            undoButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            undoButton.centerYAnchor.constraint(equalTo: buttonRow.centerYAnchor),
            undoButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        collectionView.addGestureRecognizer(longPress)
    }

    func configure(with group: SimilarAssetGroup, index: Int) {
        var reorderedAssets = group.assets
        if let bestId = group.bestAsset?.localIdentifier,
            let bestIndex = reorderedAssets.firstIndex(where: { $0.localIdentifier == bestId }),
            bestIndex != 0
        {
            let best = reorderedAssets.remove(at: bestIndex)
            reorderedAssets.insert(best, at: 0)
        }
        self.group = SimilarAssetGroup(assets: reorderedAssets, bestAsset: group.bestAsset, score: group.score)

        titleLabel.text = Strings.setTitle(index: index)
        if isStoreMode {
            exitStoreMode()
        }

        assetStates.removeAll()
        for asset in group.assets {
            if asset.localIdentifier == group.bestAsset?.localIdentifier {
                assetStates[asset.localIdentifier] = .keep
            } else {
                assetStates[asset.localIdentifier] = .delete
            }
        }

        collectionView.reloadData()
        updateConfirmButton()
    }

    func configureForProcessedState(isProcessed: Bool) {
        if isProcessed {
            if isStoreMode {
                exitStoreMode()
            }
            buttonRow.isHidden = true
            undoButton.isHidden = false
            storeButton.isUserInteractionEnabled = false
            configureStoreButtonDisabled()
            collectionView.alpha = 0.5
            collectionView.isUserInteractionEnabled = false
            containerView.alpha = 0.8
        } else {
            buttonRow.isHidden = false
            undoButton.isHidden = true
            storeButton.isUserInteractionEnabled = true
            configureStoreButtonNormal()
            collectionView.alpha = 1.0
            collectionView.isUserInteractionEnabled = true
            containerView.alpha = 1.0
            updateConfirmButton()
        }
    }

    func getAssetsByState() -> (keep: [PHAsset], delete: [PHAsset], store: [PHAsset]) {
        guard let group = group else { return ([], [], []) }
        var keep: [PHAsset] = []
        var delete: [PHAsset] = []
        var store: [PHAsset] = []
        for asset in group.assets {
            switch assetStates[asset.localIdentifier] ?? .delete {
            case .keep: keep.append(asset)
            case .delete: delete.append(asset)
            case .store: store.append(asset)
            }
        }
        return (keep, delete, store)
    }

    func exitStoreModeIfNeeded() {
        guard isStoreMode else { return }
        exitStoreMode()
    }

    func getCurrentAssetStates() -> [String: PhotoState] {
        return assetStates
    }

    private func updateConfirmButton() {
        let (keep, delete, store) = getAssetsByState()
        applyConfirmButton(keepCount: keep.count, deleteCount: delete.count, storeCount: store.count)
    }

    private func applyConfirmButton(keepCount: Int, deleteCount: Int, storeCount: Int) {
        let textFont = UIFont.systemFont(ofSize: 18, weight: .semibold)
        let separatorAttrs: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.white.withAlphaComponent(0.4)
        ]

        let result = NSMutableAttributedString()
        let entries: [(state: PhotoState, count: Int)] = [
            (.keep, keepCount),
            (.delete, deleteCount),
            (.store, storeCount)
        ]

        for entry in entries where entry.count > 0 {
            if result.length > 0 {
                result.append(NSAttributedString(string: " · ", attributes: separatorAttrs))
            }

            let iconConfig = UIImage.SymbolConfiguration(pointSize: entry.state.tagIconSize, weight: .bold)
            if let iconImage = UIImage(systemName: entry.state.tagIcon, withConfiguration: iconConfig)?
                .withTintColor(entry.state.borderColor, renderingMode: .alwaysOriginal)
            {
                let attachment = NSTextAttachment()
                attachment.image = iconImage
                let iconHeight = iconImage.size.height
                let iconWidth = iconImage.size.width
                attachment.bounds = CGRect(
                    x: 0, y: (textFont.capHeight - iconHeight) / 2, width: iconWidth, height: iconHeight)
                result.append(NSAttributedString(attachment: attachment))
            }
            let countAttrs: [NSAttributedString.Key: Any] = [
                .font: textFont,
                .foregroundColor: entry.state.borderColor
            ]
            result.append(NSAttributedString(string: " \(entry.count)", attributes: countAttrs))
        }

        result.append(
            NSAttributedString(
                string: "  \(Strings.confirm)",
                attributes: [
                    .font: textFont,
                    .foregroundColor: UIColor.white
                ]))

        confirmButton.configure(
            attributedTitle: result,
            style: .prominent,
            backgroundColor: .black,
            contentInsets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        )
    }

    private func configureStoreButtonNormal() {
        storeButton.configure(
            systemImage: "archivebox.fill",
            style: .regular,
            backgroundColor: .clear,
            foregroundColor: ThemeManager.Colors.statusYellow,
            iconSize: 14,
            contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        )
    }

    private func configureStoreButtonDisabled() {
        storeButton.configure(
            systemImage: "archivebox.fill",
            style: .prominent,
            backgroundColor: .systemGray4,
            foregroundColor: .systemGray2,
            iconSize: 14,
            contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        )
    }

    private func configureStoreButtonStoreMode() {
        storeButton.configure(
            systemImage: "checkmark",
            style: .prominent,
            backgroundColor: ThemeManager.Colors.statusGreen,
            iconSize: 14,
            contentInsets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        )
    }


    @objc private func handleConfirm() {
        exitStoreModeIfNeeded()
        delegate?.didTapConfirm(cell: self)
    }

    @objc private func handleUndo() {
        delegate?.didTapUndo(cell: self)
    }

    @objc private func handleStoreToggle() {
        if isStoreMode {
            exitStoreMode()
        } else {
            enterStoreMode()
        }
    }

    private func enterStoreMode() {
        isStoreMode = true
        configureStoreButtonStoreMode()
        for cell in collectionView.visibleCells {
            (cell as? PhotoGridCell)?.startShake()
        }
        HapticFeedbackManager.shared.impact(intensity: .medium)
    }

    private func exitStoreMode() {
        isStoreMode = false
        configureStoreButtonNormal()
        for cell in collectionView.visibleCells {
            (cell as? PhotoGridCell)?.stopShake()
        }
        HapticFeedbackManager.shared.impact(intensity: .light)
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            let point = gesture.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: point),
                let asset = group?.assets[indexPath.item]
            else { return }

            let cell = collectionView.cellForItem(at: indexPath) as? PhotoGridCell
            let thumbnail = cell?.currentImage
            showPreview(thumbnail: thumbnail, asset: asset)
            HapticFeedbackManager.shared.impact(intensity: .medium)

        case .ended, .cancelled, .failed:
            dismissPreview()

        default:
            break
        }
    }

    // MARK: - Full-Screen Preview long pres
    private func showPreview(thumbnail: UIImage?, asset: PHAsset) {
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first,
            let window = windowScene.windows.first(where: { $0.isKeyWindow })
        else { return }

        let overlay = UIView(frame: window.bounds)
        overlay.alpha = 0

        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = overlay.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addSubview(blurView)

        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = thumbnail

        overlay.addSubview(imageView)
        let padding: CGFloat = 24
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.topAnchor, constant: padding),
            imageView.bottomAnchor.constraint(equalTo: overlay.safeAreaLayoutGuide.bottomAnchor, constant: -padding),
            imageView.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: padding),
            imageView.trailingAnchor.constraint(equalTo: overlay.trailingAnchor, constant: -padding)
        ])

        window.addSubview(overlay)
        self.previewOverlay = overlay
        self.previewImageView = imageView

        imageView.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5) {
            overlay.alpha = 1
            imageView.transform = .identity
        }

        // full quality image
        let screenSize = window.bounds.size
        previewRequestID = ImageCacheService.shared.loadImage(
            for: asset,
            quality: .full,
            screenSize: screenSize,
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        ) { [weak self] image, _, _ in
            guard let self, let image else { return }
            DispatchQueue.main.async {
                self.previewImageView?.image = image
            }
        }
    }

    private func dismissPreview() {
        if let requestID = previewRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            previewRequestID = nil
        }

        guard let overlay = previewOverlay else { return }
        let imageView = previewImageView

        UIView.animate(
            withDuration: 0.2,
            animations: {
                overlay.alpha = 0
                imageView?.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        ) { _ in
            overlay.removeFromSuperview()
        }

        previewOverlay = nil
        previewImageView = nil
    }
}

extension SimilarGroupCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return group?.assets.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell =
            collectionView.dequeueReusableCell(withReuseIdentifier: PhotoGridCell.reuseIdentifier, for: indexPath)
            as! PhotoGridCell
        if let asset = group?.assets[indexPath.item] {
            cell.configure(with: asset)
            let state = assetStates[asset.localIdentifier] ?? .delete
            cell.applyState(state)
            if isStoreMode {
                cell.startShake()
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let asset = group?.assets[indexPath.item] else { return }
        delegate?.didInteractWithCell(self)

        let assetId = asset.localIdentifier
        let currentState = assetStates[assetId] ?? .delete

        if isStoreMode {
            if currentState == .store {
                let isBest = (assetId == group?.bestAsset?.localIdentifier)
                assetStates[assetId] = isBest ? .keep : .delete
            } else {
                assetStates[assetId] = .store
            }
        } else {
            switch currentState {
            case .keep: assetStates[assetId] = .delete
            case .delete: assetStates[assetId] = .keep
            case .store: assetStates[assetId] = .delete
            }
        }

        HapticFeedbackManager.shared.selection()
        collectionView.reloadItems(at: [indexPath])
        updateConfirmButton()
        delegate?.didChangeAssetStates(self, states: assetStates)
    }
}

#if DEBUG
    import SwiftUI

    private struct SimilarGroupCellPreview: UIViewRepresentable {
        let title: String
        let states: [SimilarGroupCell.PhotoState]
        let isProcessed: Bool

        func makeUIView(context: Context) -> SimilarGroupCell {
            let cell = SimilarGroupCell(style: .default, reuseIdentifier: SimilarGroupCell.reuseIdentifier)
            cell.configureForPreview(title: title, states: states)
            if isProcessed {
                cell.configureForProcessedState(isProcessed: true)
            }
            return cell
        }

        func updateUIView(_ uiView: SimilarGroupCell, context: Context) {}
    }

    extension SimilarGroupCell {
        func configureForPreview(title: String, states: [PhotoState]) {
            titleLabel.text = title
            let keepCount = states.filter { $0 == .keep }.count
            let deleteCount = states.filter { $0 == .delete }.count
            let storeCount = states.filter { $0 == .store }.count
            applyConfirmButton(keepCount: keepCount, deleteCount: deleteCount, storeCount: storeCount)
        }
    }

    #Preview("Default — 1 keep, 2 delete") {
        SimilarGroupCellPreview(
            title: "Set #1",
            states: [.keep, .delete, .delete],
            isProcessed: false
        )
        .frame(height: 280)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    #Preview("Mixed — keep, delete, store") {
        SimilarGroupCellPreview(
            title: "Set #2",
            states: [.keep, .delete, .delete, .store, .store],
            isProcessed: false
        )
        .frame(height: 280)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    #Preview("All keep") {
        SimilarGroupCellPreview(
            title: "Set #3",
            states: [.keep, .keep, .keep],
            isProcessed: false
        )
        .frame(height: 280)
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    #Preview("Processed state") {
        SimilarGroupCellPreview(
            title: "Set #4",
            states: [.keep, .delete],
            isProcessed: true
        )
        .frame(height: 280)
        .padding()
        .background(Color(.systemGroupedBackground))
    }
#endif

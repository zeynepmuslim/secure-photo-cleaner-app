//
//  UndoHistoryCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Photos
import UIKit

final class UndoHistoryCell: UITableViewCell {

    private enum Layout {
        static let capsuleLeading = GeneralConstants.EdgePadding.medium
        static let capsuleWidth = ActionRuleCapsuleView.size.width
        static let capsuleToText: CGFloat = 12
        static let thumbnailTrailing = GeneralConstants.EdgePadding.medium
        static let selectionIndicatorSize: CGFloat = 24
        static let selectionIndicatorToCapsule: CGFloat = 12
        static let selectingDuration: TimeInterval = 0.25
    }

    /// The select mode's mark: an empty ring, or a blue circle with a dot. Not a tick, which is Keep's.
    private let selectionIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 21, weight: .regular)
        imageView.alpha = 0
        imageView.isAccessibilityElement = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var capsuleLeadingConstraint: NSLayoutConstraint?
    private var isSelecting = false

    /// The capsule's leading distance: it moves in to make room for the selection mark.
    private var capsuleLeadingOffset: CGFloat {
        Layout.capsuleLeading
            + (isSelecting ? Layout.selectionIndicatorSize + Layout.selectionIndicatorToCapsule : 0)
    }

    /// The rule capsule: the action's color with its symbol (no circle) in the action's ink.
    private let capsuleView: ActionRuleCapsuleView = {
        let view = ActionRuleCapsuleView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 2
        label.lineBreakMode = .byWordWrapping
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.layer.cornerCurve = .continuous
        imageView.backgroundColor = .systemGray6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(selectionIndicator)
        contentView.addSubview(capsuleView)
        updateSelectionIndicator()
        contentView.addSubview(stackView)
        contentView.addSubview(thumbnailImageView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(timeLabel)
    }

    private func setupConstraint() {
        let capsuleLeading = capsuleView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor, constant: capsuleLeadingOffset)
        capsuleLeadingConstraint = capsuleLeading
        NSLayoutConstraint.activate([
            selectionIndicator.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: Layout.capsuleLeading),
            selectionIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            selectionIndicator.widthAnchor.constraint(equalToConstant: Layout.selectionIndicatorSize),
            selectionIndicator.heightAnchor.constraint(equalToConstant: Layout.selectionIndicatorSize),

            capsuleLeading,
            capsuleView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            capsuleView.widthAnchor.constraint(equalToConstant: Layout.capsuleWidth),
            capsuleView.heightAnchor.constraint(equalToConstant: ActionRuleCapsuleView.size.height),

            stackView.leadingAnchor.constraint(equalTo: capsuleView.trailingAnchor, constant: Layout.capsuleToText),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 12),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12),
            stackView.trailingAnchor.constraint(equalTo: thumbnailImageView.leadingAnchor, constant: -12),

            thumbnailImageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -Layout.thumbnailTrailing),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])
    }

    /// Hidden when the row below is selected, so no line cuts above a selected row's fill.
    var hidesSeparator = false {
        didSet {
            guard hidesSeparator != oldValue else { return }
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The separator starts at the text (it moves with the content in select mode).
        let leading = hidesSeparator
            ? bounds.width
            : contentView.frame.minX + capsuleLeadingOffset + Layout.capsuleWidth + Layout.capsuleToText
        if separatorInset.left != leading {
            separatorInset = UIEdgeInsets(top: 0, left: leading, bottom: 0, right: 0)
        }
    }

    // MARK: - Select mode

    /// Shows or hides the selection mark; the row's content moves in to make room for it.
    func setSelecting(_ selecting: Bool, animated: Bool) {
        guard selecting != isSelecting else { return }
        isSelecting = selecting
        capsuleLeadingConstraint?.constant = capsuleLeadingOffset
        updateSelectionIndicator()
        setNeedsLayout()
        let changes = {
            self.selectionIndicator.alpha = selecting ? 1 : 0
            self.layoutIfNeeded()
        }
        if animated, !UIAccessibility.isReduceMotionEnabled {
            UIView.animate(withDuration: Layout.selectingDuration, animations: changes)
        } else {
            changes()
        }
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        updateSelectionIndicator()
    }

    private func updateSelectionIndicator() {
        if isSelected {
            // A filled circle with a dot; the older name is a ring around the dot.
            selectionIndicator.image = UIImage(systemName: "smallcircle.filled.circle.fill")
                ?? UIImage(systemName: "circle.inset.filled")
            selectionIndicator.tintColor = .systemBlue
        } else {
            selectionIndicator.image = UIImage(systemName: "circle")
            selectionIndicator.tintColor = .systemGray3
        }
    }

    private func applyCapsule(for action: UndoAction) {
        capsuleView.configure(type: action.actionType, color: action.displayColor)
    }

    /// Selection is a fill inside the inset card (clipped to its corners), never full-bleed. Both
    /// fills are solid colors of the app's own, one step apart.
    override func updateConfiguration(using state: UICellConfigurationState) {
        var background = UIBackgroundConfiguration.listGroupedCell().updated(for: state)
        background.backgroundColor = (state.isSelected || state.isHighlighted) ? Self.selectedFill : Self.rowFill
        backgroundConfiguration = background
    }

    // The app's card color (white / #1C1C1E), on the sheet's solid grouped background.
    private static let rowFill = UIColor.cardBackground

    // .systemGray5 (light #E5E5EA, dark #2C2C2E): one step above the card, opaque.
    private static let selectedFill = UIColor.systemGray5

    func configure(with action: UndoAction, thumbnail: UIImage?) {
        applyCapsule(for: action)
        titleLabel.text = action.displayTitle
        timeLabel.text = action.timestamp.timeAgo()
        thumbnailImageView.image = thumbnail
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.backgroundColor = .systemGray6
    }

    func configureAsDeleted(with action: UndoAction) {
        applyCapsule(for: action)
        titleLabel.text = action.displayTitle
        timeLabel.text = action.timestamp.timeAgo()

        thumbnailImageView.image = UIImage(systemName: "photo.fill")
        thumbnailImageView.tintColor = .systemGray3
        thumbnailImageView.contentMode = .center
        thumbnailImageView.backgroundColor = .systemGray5
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.image = nil
        thumbnailImageView.contentMode = .scaleAspectFill

        hidesSeparator = false
        titleLabel.text = nil
        timeLabel.text = nil
    }
}

// MARK: - Previews
#if DEBUG
    import SwiftUI

    private struct UndoHistoryCellPreview: UIViewRepresentable {
        let actionType: UndoAction.ActionType
        let isDeleted: Bool

        func makeUIView(context: Context) -> UndoHistoryCell {
            let cell = UndoHistoryCell(style: .default, reuseIdentifier: nil)
            let action = Self.mockAction(actionType)
            if isDeleted {
                cell.configureAsDeleted(with: action)
            } else {
                cell.configure(with: action, thumbnail: Self.placeholderThumbnail())
            }
            return cell
        }

        func updateUIView(_ uiView: UndoHistoryCell, context: Context) {}

        private static func mockAction(_ type: UndoAction.ActionType) -> UndoAction {
            UndoAction(
                id: UUID(),
                actionType: type,
                assetLocalIdentifier: "preview-asset",
                index: 0,
                assetSize: 1024 * 1024 * 3,
                timestamp: Date() + TimeInterval(-3600),
                sessionId: UUID()
            )
        }

        private static func placeholderThumbnail() -> UIImage {
            let size = CGSize(width: 60, height: 60)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { ctx in
                UIColor.systemGray.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
            }
        }
    }

    #Preview("Delete") {
        UndoHistoryCellPreview(actionType: .delete, isDeleted: false)
    }

    #Preview("Keep") {
        UndoHistoryCellPreview(actionType: .keep, isDeleted: false)
            .frame(width: 375, height: 76)
    }

    @available(iOS 17.0, *)
    #Preview("Keep2", traits: .sizeThatFitsLayout) {
        UndoHistoryCellPreview(actionType: .keep, isDeleted: true)
    }

    #Preview("Store") {
        UndoHistoryCellPreview(actionType: .store, isDeleted: false)
    }

    #Preview("Deleted Asset") {
        UndoHistoryCellPreview(actionType: .delete, isDeleted: true)
    }

#endif

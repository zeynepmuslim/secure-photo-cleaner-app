//
//  UndoHistoryCell.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Photos
import UIKit

final class UndoHistoryCell: UITableViewCell {

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .label
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
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
        contentView.addSubview(iconImageView)
        contentView.addSubview(stackView)
        contentView.addSubview(thumbnailImageView)

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(timeLabel)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),

            stackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stackView.trailingAnchor.constraint(equalTo: thumbnailImageView.leadingAnchor, constant: -12),

            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            thumbnailImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 60),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),

            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])
    }

    func configure(with action: UndoAction, thumbnail: UIImage?) {
        iconImageView.image = UIImage(systemName: action.displayIcon)
        iconImageView.tintColor = action.displayColor
        titleLabel.text = action.displayTitle
        timeLabel.text = action.timestamp.timeAgo()
        thumbnailImageView.image = thumbnail
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.backgroundColor = .systemGray6
    }

    func configureAsDeleted(with action: UndoAction) {
        iconImageView.image = UIImage(systemName: action.displayIcon)
        iconImageView.tintColor = action.displayColor
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

        iconImageView.image = nil
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

//
//  PhotoThumbnailCell.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 1.02.2026.
//

import UIKit

final class PhotoThumbnailCell: UICollectionViewCell {

    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    var representedAssetIdentifier: String?

    private let checkmarkView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "checkmark.circle.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        )
        imageView.tintColor = .systemBlue
        imageView.backgroundColor = .white
        imageView.layer.cornerRadius = 16
        imageView.layer.masksToBounds = true
        imageView.isHidden = true
        return imageView
    }()

    private let overlayView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        view.isHidden = true
        return view
    }()

    private let iCloudBadge: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "icloud.and.arrow.down")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        )
        imageView.tintColor = .white
        imageView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        imageView.contentMode = .center
        imageView.layer.cornerRadius = 12
        imageView.layer.masksToBounds = true
        imageView.isHidden = true
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(overlayView)
        contentView.addSubview(checkmarkView)
        contentView.addSubview(iCloudBadge)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            overlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmarkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmarkView.widthAnchor.constraint(equalToConstant: 32),
            checkmarkView.heightAnchor.constraint(equalToConstant: 32),

            iCloudBadge.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            iCloudBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),
            iCloudBadge.widthAnchor.constraint(equalToConstant: 24),
            iCloudBadge.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    override var isSelected: Bool {
        didSet {
            overlayView.isHidden = !isSelected
            checkmarkView.isHidden = !isSelected
        }
    }

    func showICloudBadge(_ show: Bool) {
        iCloudBadge.isHidden = !show
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        representedAssetIdentifier = nil
        isSelected = false
        iCloudBadge.isHidden = true
    }
}

#if DEBUG
    import SwiftUI

    #Preview("Default") {
        PhotoThumbnailCellWrapper(isSelected: false, showICloud: false)
            .frame(width: 100, height: 100)
    }

    #Preview("Selected") {
        PhotoThumbnailCellWrapper(isSelected: true, showICloud: false)
            .frame(width: 100, height: 100)
    }

    #Preview("iCloud Badge") {
        PhotoThumbnailCellWrapper(isSelected: false, showICloud: true)
            .frame(width: 100, height: 100)
    }

    #Preview("Selected + iCloud") {
        PhotoThumbnailCellWrapper(isSelected: true, showICloud: true)
            .frame(width: 100, height: 100)
    }

    struct PhotoThumbnailCellWrapper: UIViewRepresentable {
        var isSelected: Bool = false
        var showICloud: Bool = false

        func makeUIView(context: Context) -> PhotoThumbnailCell {
            let cell = PhotoThumbnailCell()
            cell.imageView.image = UIImage(systemName: "photo.fill")
            cell.imageView.tintColor = .systemGray3
            cell.imageView.contentMode = .center
            cell.isSelected = isSelected
            cell.showICloudBadge(showICloud)
            return cell
        }

        func updateUIView(_ uiView: PhotoThumbnailCell, context: Context) {}
    }
#endif

//
//  PhotoGridCell.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import Photos
import UIKit

final class PhotoGridCell: UICollectionViewCell {
    static let reuseIdentifier = "PhotoGridCell"

    var currentImage: UIImage? { thumbnailView.image }

    /// The photo with its mark's border, badge and grayscale (shared with the help sheet's sample)
    private let thumbnailView: SimilarPhotoThumbnailView = {
        let view = SimilarPhotoThumbnailView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var imageRequestID: PHImageRequestID = PHInvalidImageRequestID
    private var currentAssetId: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(thumbnailView)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    func configure(with asset: PHAsset) {
        // Cancel any in-flight request from previous reuse
        if imageRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }

        currentAssetId = asset.localIdentifier
        thumbnailView.grayscaleCacheKey = asset.localIdentifier

        imageRequestID = ImageCacheService.shared.loadImage(
            for: asset,
            quality: .thumbnail,
            screenSize: CGSize(width: 200, height: 200),
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess,
            traitCollection: traitCollection
        ) { [weak self] image, _, _ in
            guard let self, self.currentAssetId == asset.localIdentifier else { return }
            self.thumbnailView.image = image
        }
    }

    func applyState(_ state: SimilarPhotoState) {
        thumbnailView.applyState(state)
    }

    func startShake() {
        thumbnailView.startShake()
    }

    func stopShake() {
        thumbnailView.stopShake()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if imageRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
            imageRequestID = PHInvalidImageRequestID
        }
        currentAssetId = nil
        thumbnailView.grayscaleCacheKey = nil
        thumbnailView.image = nil
        thumbnailView.applyState(nil)
        stopShake()
    }

}

#if DEBUG
    import SwiftUI

    private struct PhotoGridCellPreview: UIViewRepresentable {
        let state: SimilarPhotoState?

        func makeUIView(context: Context) -> PhotoGridCell {
            let cell = PhotoGridCell(frame: .zero)
            cell.configureForPreview()
            if let state {
                cell.applyState(state)
            }
            return cell
        }

        func updateUIView(_ uiView: PhotoGridCell, context: Context) {}
    }

    extension PhotoGridCell {
        func configureForPreview() {
            let size = CGSize(width: 120, height: 120)
            let renderer = UIGraphicsImageRenderer(size: size)
            let placeholder = renderer.image { ctx in
                UIColor.systemTeal.setFill()
                ctx.fill(CGRect(origin: .zero, size: size))
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28),
                    .foregroundColor: UIColor.white
                ]
                let text = "🏔"
                let textSize = text.size(withAttributes: attrs)
                let point = CGPoint(
                    x: (size.width - textSize.width) / 2,
                    y: (size.height - textSize.height) / 2
                )
                text.draw(at: point, withAttributes: attrs)
            }
            thumbnailView.image = placeholder
        }
    }

    #Preview("Default") {
        PhotoGridCellPreview(state: nil)
            .frame(width: 120, height: 120)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    #Preview("Delete state") {
        PhotoGridCellPreview(state: .delete)
            .frame(width: 120, height: 120)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    #Preview("Keep state") {
        PhotoGridCellPreview(state: .keep)
            .frame(width: 120, height: 120)
            .padding()
            .background(Color(.systemGroupedBackground))
    }

    #Preview("Store state") {
        PhotoGridCellPreview(state: .store)
            .frame(width: 120, height: 120)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
#endif

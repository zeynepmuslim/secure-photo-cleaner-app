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

    var currentImage: UIImage? { imageView.image }

    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let imageOverlayView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 8
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let stateOverlayContainer: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let stateIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var imageRequestID: PHImageRequestID = PHInvalidImageRequestID
    private var currentAssetId: String?
    private var originalImage: UIImage?
    private var currentState: SimilarGroupCell.PhotoState?

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 8
        clipsToBounds = true
        setupUI()
        setupConstraint()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(imageOverlayView)
        contentView.addSubview(stateOverlayContainer)
        stateOverlayContainer.addSubview(stateIconView)
    }

    private func setupConstraint() {
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            imageOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            imageOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            imageOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            imageOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),

            stateOverlayContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            stateOverlayContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            stateOverlayContainer.widthAnchor.constraint(equalToConstant: 24),
            stateOverlayContainer.heightAnchor.constraint(equalToConstant: 24),

            stateIconView.centerXAnchor.constraint(equalTo: stateOverlayContainer.centerXAnchor),
            stateIconView.centerYAnchor.constraint(equalTo: stateOverlayContainer.centerYAnchor),
            stateIconView.widthAnchor.constraint(equalToConstant: 20),
            stateIconView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(with asset: PHAsset) {
        // Cancel any in-flight request from previous reuse
        if imageRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
        }

        currentAssetId = asset.localIdentifier

        imageRequestID = ImageCacheService.shared.loadImage(
            for: asset,
            quality: .thumbnail,
            screenSize: CGSize(width: 200, height: 200),
            allowNetworkAccess: SettingsStore.shared.allowInternetAccess
        ) { [weak self] image, _, _ in
            guard let self, self.currentAssetId == asset.localIdentifier else { return }
            self.originalImage = image
            if self.currentState == .delete {
                self.imageView.image = image.flatMap { GrayscaleConverter.apply(to: $0) } ?? image
            } else {
                self.imageView.image = image
            }
        }
    }

    func applyState(_ state: SimilarGroupCell.PhotoState) {
        currentState = state
        contentView.layer.borderColor = state.borderColor.cgColor
        contentView.layer.borderWidth = 3
        contentView.layer.cornerRadius = 8

        stateOverlayContainer.isHidden = false
        stateOverlayContainer.backgroundColor = state.overlayColor
        stateIconView.image = UIImage(systemName: state.overlayIcon)

        switch state {
        case .delete:
            imageView.image = originalImage.flatMap { GrayscaleConverter.apply(to: $0) } ?? originalImage
            imageOverlayView.isHidden = true
        case .store:
            imageView.image = originalImage
            imageOverlayView.backgroundColor = UIColor.yellow.withAlphaComponent(0.25)
            imageOverlayView.isHidden = false
        case .keep:
            imageView.image = originalImage
            imageOverlayView.isHidden = true
        }
    }

    func startShake() {
        guard layer.animation(forKey: "wiggle") == nil else { return }
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation")
        animation.values = [-0.03, 0.03, -0.03]
        animation.duration = 0.25
        animation.repeatCount = .infinity
        layer.add(animation, forKey: "wiggle")
    }

    func stopShake() {
        layer.removeAnimation(forKey: "wiggle")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if imageRequestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(imageRequestID)
            imageRequestID = PHInvalidImageRequestID
        }
        currentAssetId = nil
        imageView.image = nil
        originalImage = nil
        currentState = nil
        contentView.layer.borderColor = UIColor.clear.cgColor
        contentView.layer.borderWidth = 0
        stateOverlayContainer.isHidden = true
        imageOverlayView.isHidden = true
        stopShake()
    }

}

#if DEBUG
    import SwiftUI

    private struct PhotoGridCellPreview: UIViewRepresentable {
        let state: SimilarGroupCell.PhotoState?

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
            originalImage = placeholder
            imageView.image = placeholder
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

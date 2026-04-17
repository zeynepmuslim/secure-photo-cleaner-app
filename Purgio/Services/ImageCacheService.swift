//
//  ImageCacheService.swift
//  Purgio
//
//  Created by ZeynepMüslim on 13.01.2026.
//

import Photos
import UIKit

final class ImageCacheService {
    static let shared = ImageCacheService()

    private let cache = NSCache<NSString, UIImage>()
    private let imageManager = PHCachingImageManager()
    private let screenScale: CGFloat
    private var keysByAsset: [String: Set<NSString>] = [:]

    enum ImageQuality {
        case thumbnail
        case preview
        case full

        var deliveryMode: PHImageRequestOptionsDeliveryMode {
            switch self {
            case .thumbnail: return .opportunistic   // locally-cached even icloud
            case .preview: return .opportunistic
            case .full: return .highQualityFormat
            }
        }

        func targetSize(for screenSize: CGSize, scale: CGFloat) -> CGSize {
            switch self {
            case .thumbnail:
                return CGSize(width: 200 * scale, height: 200 * scale)
            case .preview:
                return CGSize(width: screenSize.width * scale * 0.7, height: screenSize.height * scale * 0.7)
            case .full:
                return CGSize(width: screenSize.width * scale, height: screenSize.height * scale)
            }
        }
    }

    private init() {
        self.screenScale = UIScreen.main.scale

        cache.totalCostLimit = 30 * 1024 * 1024
        cache.countLimit = 15

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    private func cacheKey(for assetIdentifier: String, size: CGSize, quality: ImageQuality) -> NSString {
        return "\(assetIdentifier)_\(Int(size.width))x\(Int(size.height))_\(quality)" as NSString
    }

    private func cost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let bytesPerPixel = 4
        return cgImage.width * cgImage.height * bytesPerPixel
    }

    func setImage(_ image: UIImage, for assetIdentifier: String, size: CGSize, quality: ImageQuality) {
        let key = cacheKey(for: assetIdentifier, size: size, quality: quality)
        let imageCost = cost(for: image)
        cache.setObject(image, forKey: key, cost: imageCost)
        keysByAsset[assetIdentifier, default: []].insert(key)
    }

    func getImage(for assetIdentifier: String, size: CGSize, quality: ImageQuality) -> UIImage? {
        let key = cacheKey(for: assetIdentifier, size: size, quality: quality)
        return cache.object(forKey: key)
    }
    
    func clearCache() {
        cache.removeAllObjects()
        keysByAsset.removeAll()
    }

    func clearCache(for assetIdentifier: String) {
        guard let keys = keysByAsset.removeValue(forKey: assetIdentifier) else { return }
        for key in keys {
            cache.removeObject(forKey: key)
        }
    }

    @objc private func handleMemoryWarning() {
        print("Memory warning - clearing image cache")
        iCloudSyncLogger.shared.logCacheCleared(reason: "memory_warning")
        clearCache()
    }

    @discardableResult
    func loadImage(
        for asset: PHAsset,
        quality: ImageQuality,
        screenSize: CGSize,
        allowNetworkAccess: Bool,
        completion: @escaping (UIImage?, Bool, Bool) -> Void   // (image, isInCloud, isDegraded)
    ) -> PHImageRequestID {
        let targetSize = quality.targetSize(for: screenSize, scale: screenScale)

        if let cachedImage = getImage(for: asset.localIdentifier, size: targetSize, quality: quality) {
            let isInCloud = asset.isCloudOnly
            completion(cachedImage, isInCloud, false)
            return PHInvalidImageRequestID
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = quality.deliveryMode
        options.isNetworkAccessAllowed = allowNetworkAccess
        options.isSynchronous = false
        options.resizeMode = .fast

        options.progressHandler = { _, error, _, _ in
            if let error = error {
                iCloudSyncLogger.shared.logDownloadFailed(assetId: asset.localIdentifier, error: error)
            }
        }

        return imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, info in
            let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool ?? false
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let error = info?[PHImageErrorKey] as? Error

            if isInCloud && !allowNetworkAccess && image == nil {
                iCloudSyncLogger.shared.logBlockedNetworkRequest(
                    assetId: asset.localIdentifier, reason: "Network access disabled by user")
            }

            if let error = error {
                iCloudSyncLogger.shared.logDownloadFailed(assetId: asset.localIdentifier, error: error)
            } else if allowNetworkAccess && !isDegraded {
                iCloudSyncLogger.shared.logDownloadCompleted(
                    assetId: asset.localIdentifier, success: image != nil, wasDegraded: isDegraded)
            }

            guard let self = self else {
                completion(nil, isInCloud, isDegraded)
                return
            }

            guard let image = image else {
                // Fallback: if image is nil and asset is in iCloud, retry with
                // .fastFormat and a small size to grab any local low-quality thumbnail
                if isInCloud {
                    let retryOptions = PHImageRequestOptions()
                    retryOptions.deliveryMode = .fastFormat
                    retryOptions.isNetworkAccessAllowed = false
                    retryOptions.isSynchronous = false
                    retryOptions.resizeMode = .fast
                    let lowResSize = CGSize(width: 100, height: 100)
                    self.imageManager.requestImage(
                        for: asset,
                        targetSize: lowResSize,
                        contentMode: .aspectFill,
                        options: retryOptions
                    ) { retryImage, _ in
                        completion(retryImage, isInCloud, false)
                    }
                } else {
                    completion(nil, isInCloud, false)
                }
                return
            }

            if !isDegraded {
                self.setImage(image, for: asset.localIdentifier, size: targetSize, quality: quality)
            }

            completion(image, isInCloud, isDegraded)
        }
    }

    func startCaching(assets: [PHAsset], quality: ImageQuality, screenSize: CGSize) {
        let targetSize = quality.targetSize(for: screenSize, scale: screenScale)

        let options = PHImageRequestOptions()
        options.deliveryMode = quality.deliveryMode
        options.isNetworkAccessAllowed = SettingsStore.shared.allowInternetAccess

        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCaching(assets: [PHAsset], quality: ImageQuality, screenSize: CGSize) {
        let targetSize = quality.targetSize(for: screenSize, scale: screenScale)

        let options = PHImageRequestOptions()
        options.deliveryMode = quality.deliveryMode

        imageManager.stopCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        )
    }

    func stopCachingAllImages() {
        imageManager.stopCachingImagesForAllAssets()
    }
}

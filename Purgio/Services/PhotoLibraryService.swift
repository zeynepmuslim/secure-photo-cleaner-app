//
//  PhotoLibraryService.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.01.2026.
//

import Photos

final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {
    static let shared = PhotoLibraryService()

    private override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        invalidateMonthBucketsCache()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .photoLibraryDidChange, object: nil)
        }
    }

    struct MonthBucket {
        let key: String
        let title: String
        let totalCount: Int
    }

    private let cacheQueue = DispatchQueue(label: "com.purgio.monthBucketsCache")
    private var photoBucketsCache: [MonthBucket]?
    private var videoBucketsCache: [MonthBucket]?
    private var photoCachedYears: [String]?
    private var videoCachedYears: [String]?
    private var photoCacheDate: Date?
    private var videoCacheDate: Date?
    private let cacheValidityInterval: TimeInterval = 300   // 5 minutes

    /// Returns cached month buckets if available and valid, otherwise nil
    func getCachedMonthBuckets(mediaType: PHAssetMediaType) -> [MonthBucket]? {
        cacheQueue.sync {
            let (cache, cacheDate) =
                mediaType == .image
                ? (photoBucketsCache, photoCacheDate)
                : (videoBucketsCache, videoCacheDate)

            guard let buckets = cache,
                let date = cacheDate,
                Date().timeIntervalSince(date) < cacheValidityInterval
            else {
                return nil
            }
            return buckets
        }
    }

    /// Returns cached years if available and valid, otherwise empty array
    func getCachedYears(mediaType: PHAssetMediaType) -> [String] {
        cacheQueue.sync {
            let (years, cacheDate) =
                mediaType == .image
                ? (photoCachedYears, photoCacheDate)
                : (videoCachedYears, videoCacheDate)

            guard let cachedYears = years,
                let date = cacheDate,
                Date().timeIntervalSince(date) < cacheValidityInterval
            else {
                return []
            }
            return cachedYears
        }
    }

    func preloadMonthBucketsCache() {
        Task(priority: .utility) {
            async let photos = self.loadMonthBuckets(mediaType: .image)
            async let videos = self.loadMonthBuckets(mediaType: .video)
            _ = await (photos, videos)
            print("[PhotoLibraryService] Month buckets cache preloaded")
        }
    }

    func invalidateMonthBucketsCache() {
        cacheQueue.sync {
            photoBucketsCache = nil
            videoBucketsCache = nil
            photoCacheDate = nil
            videoCacheDate = nil
            photoCachedYears = nil
            videoCachedYears = nil
        }
        print("[PhotoLibraryService] Month buckets cache invalidated")
    }

    private func setCachedMonthBuckets(_ buckets: [MonthBucket], mediaType: PHAssetMediaType) {
        let years = Set(buckets.compactMap { $0.key.components(separatedBy: "-").first })
            .sorted(by: >)
        cacheQueue.sync {
            if mediaType == .image {
                photoBucketsCache = buckets
                photoCacheDate = Date()
                photoCachedYears = years
            } else {
                videoBucketsCache = buckets
                videoCacheDate = Date()
                videoCachedYears = years
            }
        }
    }

    func authorizationStatus() -> PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    func loadMonthBuckets(mediaType: PHAssetMediaType = .image) async -> [MonthBucket] {
        let status = authorizationStatus()
        if status != .authorized && status != .limited {
            print("[PhotoLibraryService] loadMonthBuckets blocked by auth status: \(status.rawValue)")
            return []
        }

        if let cached = getCachedMonthBuckets(mediaType: mediaType) {
            return cached
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(key: "creationDate", ascending: true)
                ]
                fetchOptions.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)

                let assets = PHAsset.fetchAssets(with: fetchOptions)
                var buckets: [String: (date: Date, count: Int)] = [:]
                let calendar = Calendar.current
                let dateManager = DateFormatterManager.shared

                if assets.count == 0 {
                    print("[PhotoLibraryService] loadMonthBuckets fetched 0 assets for mediaType \(mediaType.rawValue)")
                }

                assets.enumerateObjects { asset, _, _ in
                    guard let creationDate = asset.creationDate else { return }
                    let components = calendar.dateComponents([.year, .month], from: creationDate)
                    guard let bucketDate = calendar.date(from: components) else { return }
                    let key = dateManager.monthKey(from: bucketDate)
                    if let existing = buckets[key] {
                        buckets[key] = (existing.date, existing.count + 1)
                    } else {
                        buckets[key] = (bucketDate, 1)
                    }
                }

                let sortedBuckets =
                    buckets
                    .map { (key: $0.key, date: $0.value.date, count: $0.value.count) }
                    .sorted { $0.date > $1.date }
                    .map {
                        MonthBucket(key: $0.key, title: dateManager.displayMonth(from: $0.date), totalCount: $0.count)
                    }

                self?.setCachedMonthBuckets(sortedBuckets, mediaType: mediaType)

                continuation.resume(returning: sortedBuckets)
            }
        }
    }

    func fetchAssets(withLocalIdentifiers identifiers: [String]) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
                var assets: [PHAsset] = []
                fetchResult.enumerateObjects { asset, _, _ in
                    assets.append(asset)
                }
                continuation.resume(returning: assets)
            }
        }
    }

    func countBinAssets(withLocalIdentifiers ids: [String], inMonthKey monthKey: String) async -> Int {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let dateRange = DateFormatterManager.shared.monthDateRange(forMonthKey: monthKey) else {
                    continuation.resume(returning: 0)
                    return
                }
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                var count = 0
                fetchResult.enumerateObjects { asset, _, _ in
                    guard let date = asset.creationDate else { return }
                    if date >= dateRange.start && date < dateRange.end {
                        count += 1
                    }
                }
                continuation.resume(returning: count)
            }
        }
    }

    func fetchPhotos(forMonthKey monthKey: String, mediaType: PHAssetMediaType = .image) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(key: "creationDate", ascending: true)
                ]
                fetchOptions.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)

                if let dateRange = DateFormatterManager.shared.monthDateRange(forMonthKey: monthKey) {
                    let datePredicate = NSPredicate(
                        format: "creationDate >= %@ AND creationDate < %@", dateRange.start as NSDate,
                        dateRange.end as NSDate)
                    let mediaPredicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)
                    fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                        mediaPredicate, datePredicate
                    ])

                    let assets = PHAsset.fetchAssets(with: fetchOptions)
                    var matchedAssets: [PHAsset] = []

                    assets.enumerateObjects { asset, _, _ in
                        matchedAssets.append(asset)
                    }

                    continuation.resume(returning: matchedAssets)
                } else {   // Fallback to old method
                    let assets = PHAsset.fetchAssets(with: fetchOptions)
                    var matchedAssets: [PHAsset] = []
                    let calendar = Calendar.current
                    let dateManager = DateFormatterManager.shared

                    assets.enumerateObjects { asset, _, _ in
                        guard let creationDate = asset.creationDate else { return }
                        let components = calendar.dateComponents([.year, .month], from: creationDate)
                        guard let bucketDate = calendar.date(from: components) else { return }
                        let key = dateManager.monthKey(from: bucketDate)
                        if key == monthKey {
                            matchedAssets.append(asset)
                        }
                    }
                    continuation.resume(returning: matchedAssets)
                }
            }
        }
    }

    // MARK: - Smart Filters

    /// Fetch all photos (not grouped by month)
    func fetchAllPhotos(mediaType: PHAssetMediaType = .image) async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(key: "creationDate", ascending: false)
                ]
                fetchOptions.predicate = NSPredicate(format: "mediaType == %d", mediaType.rawValue)

                let assets = PHAsset.fetchAssets(with: fetchOptions)
                var allAssets: [PHAsset] = []

                assets.enumerateObjects { asset, _, _ in
                    allAssets.append(asset)
                }

                continuation.resume(returning: allAssets)
            }
        }
    }

    /// Fetch only screenshots
    func fetchScreenshots() async -> [PHAsset] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [
                    NSSortDescriptor(key: "creationDate", ascending: false)
                ]
                fetchOptions.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue),
                    NSPredicate(format: "(mediaSubtypes & %d) != 0", PHAssetMediaSubtype.photoScreenshot.rawValue)
                ])

                let assets = PHAsset.fetchAssets(with: fetchOptions)
                var result: [PHAsset] = []
                assets.enumerateObjects { asset, _, _ in
                    result.append(asset)
                }
                continuation.resume(returning: result)
            }
        }
    }

    /// Check if a month contains any iCloud-only assets
    func hasICloudOnlyAssets(forMonthKey monthKey: String) async -> Bool {
        let assets = await fetchPhotos(forMonthKey: monthKey)

        for asset in assets {
            if asset.isCloudOnly {
                return true
            }
        }
        return false
    }

    // MARK: - Will Be Stored Album Management

    /// Get or create the "Will Be Stored" album
    func getOrCreateWillBeStoredAlbum() async -> PHAssetCollection? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let albumName = "Will Be Stored"

                // Check if album already exists
                let fetchOptions = PHFetchOptions()
                fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .album, subtype: .any, options: fetchOptions)

                if let existingAlbum = collections.firstObject {
                    continuation.resume(returning: existingAlbum)
                    return
                }

                //then create it
                var albumPlaceholder: PHObjectPlaceholder?
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(
                            withTitle: albumName)
                        albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                    }

                    // Fetch the newly created album
                    if let placeholder = albumPlaceholder,
                        let album = PHAssetCollection.fetchAssetCollections(
                            withLocalIdentifiers: [placeholder.localIdentifier], options: nil
                        ).firstObject
                    {
                        continuation.resume(returning: album)
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    print("Error creating 'Will Be Stored' album: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Add an asset to the "Will Be Stored" album
    func addAssetToWillBeStoredAlbum(asset: PHAsset) async -> Bool {
        guard let album = await getOrCreateWillBeStoredAlbum() else {
            print("Failed to get or create 'Will Be Stored' album")
            return false
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var success = false
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        guard let addAssetRequest = PHAssetCollectionChangeRequest(for: album) else {
                            return
                        }
                        addAssetRequest.addAssets([asset] as NSArray)
                        success = true
                    }
                    continuation.resume(returning: success)
                } catch {
                    print("Error adding asset to 'Will Be Stored' album: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    func removeAssetFromWillBeStoredAlbum(asset: PHAsset) async -> Bool {
        guard let album = await getOrCreateWillBeStoredAlbum() else {
            print("Failed to get or create 'Will Be Stored' album")
            return false
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var success = false
                do {
                    try PHPhotoLibrary.shared().performChangesAndWait {
                        guard let removeAssetRequest = PHAssetCollectionChangeRequest(for: album) else {
                            return
                        }
                        removeAssetRequest.removeAssets([asset] as NSArray)
                        success = true
                    }
                    continuation.resume(returning: success)
                } catch {
                    print("Error removing asset from 'Will Be Stored' album: \(error)")
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let photoLibraryDidChange = Notification.Name("photoLibraryDidChange")
}

//
//  EyeBlinkDetector.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import CoreImage
import Foundation
import Photos
import UIKit

actor EyeBlinkDetector {

    static let shared = EyeBlinkDetector()

    private let context = CIContext(options: [CIContextOption.useSoftwareRenderer: false])
    nonisolated private let storageQueue = DispatchQueue(label: "com.galary.EyeBlinkDetector.storage")
    nonisolated private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("SecurePhotoCleaner/eyeBlinkCache.json")
    }()

    private static let maxCacheSize = 5000
    private var resultsCache: [String: Bool] = [:]
    private var cacheInsertionOrder: [String] = []

    private var persistTask: Task<Void, Never>?

    init() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        if let fileData = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode([String: Bool].self, from: fileData)
        {
            resultsCache = decoded
            cacheInsertionOrder = Array(decoded.keys)
        }
    }

    func createReusableDetector() -> CIDetector? {
        let options = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        return CIDetector(ofType: CIDetectorTypeFace, context: context, options: options)
    }
    
    func hasClosedEyes(asset: PHAsset, using passedDetector: CIDetector? = nil) async -> Bool {

        if let cachedResult = getCachedResult(for: asset.localIdentifier) {
            return cachedResult
        }

        return await withTaskGroup(of: Bool?.self) { group in
            group.addTask {
                return await self.performDetection(asset: asset, using: passedDetector)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                return nil // nil = timeout
            }

            for await result in group {
                if let result = result {
                    group.cancelAll()
                    return result
                }
            }
            group.cancelAll()
            return false // timeout — don't cache
        }
    }

    func flushCache() {
        persistTask?.cancel()
        persistToDisk(snapshot: resultsCache)
    }

    /// Remove cache entries for assets that no longer exist in the photo library
    func pruneDeletedAssets() {
        let cachedIds = Array(resultsCache.keys)
        guard !cachedIds.isEmpty else { return }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: cachedIds, options: nil)
        var existingIds = Set<String>()
        fetchResult.enumerateObjects { asset, _, _ in
            existingIds.insert(asset.localIdentifier)
        }

        let orphanIds = cachedIds.filter { !existingIds.contains($0) }
        for id in orphanIds {
            resultsCache.removeValue(forKey: id)
        }
        cacheInsertionOrder.removeAll { orphanIds.contains($0) }

        if !orphanIds.isEmpty {
            schedulePersist()
        }
    }

    // MARK: - Detection Logic
    private func performDetection(asset: PHAsset, using passedDetector: CIDetector?) async -> Bool {
        return await withCheckedContinuation { continuation in
            let screenSize = CGSize(width: 1024, height: 1024)

            var didResume = false
            let resumeLock = NSLock()

            func safeResume(with value: Bool, shouldCache: Bool) {
                resumeLock.lock()
                defer { resumeLock.unlock() }

                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)

                if shouldCache {
                    Task {
                        await self.cacheResult(for: asset.localIdentifier, isClosed: value)
                    }
                }
            }

            ImageCacheService.shared.loadImage(
                for: asset,
                quality: .preview,
                screenSize: screenSize,
                allowNetworkAccess: SettingsStore.shared.allowInternetAccess
            ) { image, _, isDegraded in
                let networkAllowed = SettingsStore.shared.allowInternetAccess
                if isDegraded && networkAllowed { return }

                guard let image = image, let ciImage = CIImage(image: image) else {
                    safeResume(with: false, shouldCache: false)
                    return
                }

                var detector = passedDetector
                if detector == nil {
                    let detectorOptions = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
                    detector = CIDetector(ofType: CIDetectorTypeFace, context: self.context, options: detectorOptions)
                }

                guard let finalDetector = detector else {
                    safeResume(with: false, shouldCache: false)
                    return
                }

                let features = finalDetector.features(in: ciImage, options: [CIDetectorEyeBlink: true])

                let faceFeatures = features.compactMap { $0 as? CIFaceFeature }
                guard !faceFeatures.isEmpty else {
                    safeResume(with: false, shouldCache: false)
                    return
                }
 
                //largest face coordites to handle mistaken bacground faces /public place selfies
                let mainFace = faceFeatures.max(by: {
                    $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height
                })!

                let closedEyesDetected = mainFace.leftEyeClosed && mainFace.rightEyeClosed

                safeResume(with: closedEyesDetected, shouldCache: true)
            }
        }
    }

    private func getCachedResult(for id: String) -> Bool? {
        return resultsCache[id]
    }

    private func cacheResult(for id: String, isClosed: Bool) {
        if resultsCache[id] == nil {
            cacheInsertionOrder.append(id)
            if resultsCache.count >= Self.maxCacheSize {
                let evictCount = resultsCache.count - Self.maxCacheSize + 1
                let toEvict = Array(cacheInsertionOrder.prefix(evictCount))
                for evictId in toEvict {
                    resultsCache.removeValue(forKey: evictId)
                }
                cacheInsertionOrder.removeFirst(evictCount)
            }
        }
        resultsCache[id] = isClosed
        schedulePersist()
    }

    private func schedulePersist() {
        persistTask?.cancel()
        let snapshot = resultsCache
        persistTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // debounce for 2 seconds
            guard !Task.isCancelled else { return }
            persistToDisk(snapshot: snapshot)
        }
    }

    nonisolated private func persistToDisk(snapshot: [String: Bool]) {
        let url = fileURL
        storageQueue.async {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: url, options: [.atomic])
            }
        }
    }
}

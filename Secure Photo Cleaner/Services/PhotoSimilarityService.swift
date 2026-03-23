//
//  PhotoSimilarityService.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Foundation
import Photos
import Vision
import UIKit

class PhotoSimilarityService {
    
    static let shared = PhotoSimilarityService()
    private init() {}
    
    private let timeIntervalThreshold: TimeInterval = 120 // 2 minutes window for grouping
    private let similarityDistanceThreshold: Float = 10.0
    
    func findSimilarPhotos(assets: [PHAsset]? = nil, completion: @escaping ([SimilarAssetGroup]) -> Void) {
        #if DEBUG
//        print("SIMILAR PHOTOS DETECTION STARTED")
        #endif

        DispatchQueue.global(qos: .userInitiated).async {
//            let scanStart = CFAbsoluteTimeGetCurrent()
            var assetsToProcess: [PHAsset] = []

            if let inputAssets = assets {
                assetsToProcess = inputAssets.sorted {
                    ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast)
                }
            } else {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
                fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

                let allAssets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                allAssets.enumerateObjects { asset, _, _ in
                    assetsToProcess.append(asset)
                }
            }

            guard !assetsToProcess.isEmpty else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let clusters = self.clusterAssetsByDate(assets: assetsToProcess)

            var similarGroups: [SimilarAssetGroup] = []
            let similarGroupsLock = NSLock()

            let group = DispatchGroup()

            for cluster in clusters {
                if cluster.count < 2 { continue }

                group.enter()
                self.processClusterInBatches(cluster) { groups in
                    if !groups.isEmpty {
                        similarGroupsLock.lock()
                        similarGroups.append(contentsOf: groups)
                        similarGroupsLock.unlock()
                    }
                    group.leave()
                }
            }

            group.wait()

            #if DEBUG
//            print("[PhotoSimilarity] total scan took \(Int((CFAbsoluteTimeGetCurrent() - scanStart) * 1000))ms for \(assetsToProcess.count) assets → \(similarGroups.count) groups")
            #endif

            DispatchQueue.main.async {
                completion(similarGroups)
            }
        }
    }
    
    // MARK: - Step 1: Clustering
    
    /// Groups assets that are close in time
    private func clusterAssetsByDate(assets: [PHAsset]) -> [[PHAsset]] {
        var clusters: [[PHAsset]] = []
        var currentCluster: [PHAsset] = []
        
        for asset in assets {
            guard let currentDate = asset.creationDate else { continue }
            
            if let lastAsset = currentCluster.last,
               let lastDate = lastAsset.creationDate {
                
                if currentDate.timeIntervalSince(lastDate) <= timeIntervalThreshold {
                    currentCluster.append(asset)
                } else {
                    clusters.append(currentCluster) // gap to large new cluster
                    currentCluster = [asset]
                }
            } else {
                currentCluster.append(asset)
            }
        }
        
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        
        return clusters
    }
    
    // MARK: - Step 2: Vision Processing
    private func processClusterInBatches(_ assets: [PHAsset], completion: @escaping ([SimilarAssetGroup]) -> Void) {
        let batchSize = 5

        var observations: [String: VNFeaturePrintObservation] = [:]
        let observationsQueue = DispatchQueue(label: "com.securephotocleaner.observations", attributes: .concurrent)

        var completedAssets = Set<String>()
        let completedAssetsLock = NSLock()

        let targetSize = CGSize(width: 128, height: 128)

        let group = DispatchGroup()

        #if DEBUG
//        print("PhotoSimilarity: Processing \(assets.count) assets in batches of \(batchSize), target size: \(targetSize)")
        #endif

        for batchStart in stride(from: 0, to: assets.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, assets.count)
            let batch = Array(assets[batchStart..<batchEnd])

            autoreleasepool {
                for asset in batch {
                    group.enter()
                    let assetId = asset.localIdentifier

                    ImageCacheService.shared.loadImage(
                        for: asset,
                        quality: .thumbnail,
                        screenSize: targetSize,
                        allowNetworkAccess: SettingsStore.shared.allowInternetAccess
                    ) { image, _, isDegraded in
                        completedAssetsLock.lock()
                        let alreadyCompleted = completedAssets.contains(assetId)
                        if !alreadyCompleted {
                            completedAssets.insert(assetId)
                        }
                        completedAssetsLock.unlock()

                        guard !alreadyCompleted else { return }

                        guard let image = image, let cgImage = image.cgImage else {
                            group.leave()
                            return
                        }

                        // Dispatch Vision processing to background — PHImageManager may deliver on main thread
                        DispatchQueue.global(qos: .userInitiated).async {
                            autoreleasepool {
                                let request = VNGenerateImageFeaturePrintRequest()
                                #if targetEnvironment(simulator)
                                request.usesCPUOnly = true
                                #endif

                                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                                do {
                                    try handler.perform([request])
                                    if let observation = request.results?.first as? VNFeaturePrintObservation {
                                        observationsQueue.async(flags: .barrier) {
                                            observations[asset.localIdentifier] = observation
                                        }
                                    }
                                } catch {
                                    print("Vision failed for asset \(asset.localIdentifier): \(error)")
                                }
                            }
                            group.leave()
                        }
                    }
                }

                let waitResult = group.wait(timeout: .now() + 30)
                if waitResult == .timedOut {
                    print("[PhotoSimilarity] Warning: Batch timed out, continuing with available results")
                }
            }
        }
        
        // batches processed -> compare observations
        var observationsCopy: [String: VNFeaturePrintObservation] = [:]
        observationsQueue.sync {
            observationsCopy = observations
        }
        
        let groups = findSimilarGroupsFromObservations(assets: assets, observations: observationsCopy)
        
        let obsCount = observationsCopy.count
        observationsCopy.removeAll()
        observations.removeAll()
        #if DEBUG
//        print("PhotoSimilarity: Released \(obsCount) observations, found \(groups.count) similar groups")
        #endif
        
        completion(groups)
    }
    
    // MARK: - Step 3: Comparison
    private func findSimilarGroupsFromObservations(assets: [PHAsset], observations: [String: VNFeaturePrintObservation]) -> [SimilarAssetGroup] {
        var visited = Set<String>()
        var groups: [SimilarAssetGroup] = []
        
        for i in 0..<assets.count {
            let assetA = assets[i]
            if visited.contains(assetA.localIdentifier) { continue }
            
            guard observations[assetA.localIdentifier] != nil else { continue }
            
            var currentGroupAssets: [PHAsset] = [assetA]
            visited.insert(assetA.localIdentifier)
            
            for j in (i+1)..<assets.count {
                let assetB = assets[j]
                if visited.contains(assetB.localIdentifier) { continue }
                
                guard let obsB = observations[assetB.localIdentifier] else { continue }
                
                do {
                    var isSimilarToAll = true
                    for existingAsset in currentGroupAssets {
                        guard let existingObs = observations[existingAsset.localIdentifier] else {
                            isSimilarToAll = false
                            break
                        }
                        var distance: Float = 0
                        try existingObs.computeDistance(&distance, to: obsB)
                        if distance >= similarityDistanceThreshold {
                            isSimilarToAll = false
                            break
                        }
                    }

                    if isSimilarToAll {
                        currentGroupAssets.append(assetB)
                        visited.insert(assetB.localIdentifier)
                    }
                } catch {
                    print("Distance computation failed: \(error)")
                }
            }
            
            if currentGroupAssets.count > 1 {
                let best = currentGroupAssets.first(where: { $0.isFavorite }) ?? currentGroupAssets.first
                
                groups.append(SimilarAssetGroup(assets: currentGroupAssets, bestAsset: best))
            }
        }
        
        return groups
    }
}

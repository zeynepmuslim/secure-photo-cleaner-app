//
//  PhotoProcessor.swift
//  Purgio
//
//  Created by ZeynepMüslim on 6.02.2026.
//

import Photos

struct ProcessingProgress {
    let current: Int
    let total: Int
    /// What the filter has turned up so far: photos with closed eyes, or items over
    /// `GeneralConstants.LargeFile`'s size for their media type. 0 for pipelines that don't
    /// look for anything.
    var found: Int = 0
}

enum ProcessingResult {
    case progress(ProcessingProgress)
    case initialBatchReady([ReviewAsset])
    case completed([ReviewAsset])
    case cancelled
}

actor PhotoProcessor {
    static let shared = PhotoProcessor()
    private init() {}

    func processAssets(
        _ assets: [PHAsset],
        progressInterval: Int = 1,
        initialBatchSize: Int = 50
    ) -> AsyncStream<ProcessingResult> {
        AsyncStream { continuation in
            Task {
                var reviewAssets: [ReviewAsset] = []
                let total = assets.count

                for (index, asset) in assets.enumerated() {
                    if Task.isCancelled {
                        continuation.yield(.cancelled)
                        continuation.finish()
                        return
                    }

                    let metadata = asset.resourceMetadata()
                    reviewAssets.append(ReviewAsset(asset: asset, isCloudOnly: metadata.isCloudOnly, fileSize: metadata.fileSize))

                    if reviewAssets.count == initialBatchSize && total > initialBatchSize {
                        continuation.yield(.initialBatchReady(reviewAssets))
                    }

                    if (index + 1) % progressInterval == 0 || index == total - 1 {
                        continuation.yield(.progress(ProcessingProgress(current: index + 1, total: total)))
                    }
                }

                if Task.isCancelled {
                    continuation.yield(.cancelled)
                } else {
                    continuation.yield(.completed(reviewAssets))
                }
                continuation.finish()
            }
        }
    }

    func processAssetsForLargeFiles(
        _ assets: [PHAsset],
        progressInterval: Int = 1
    ) -> AsyncStream<ProcessingResult> {
        AsyncStream { continuation in
            Task {
                var reviewAssets: [ReviewAsset] = []
                let total = assets.count
                // Only feeds the loading screen's count; the result is still every item by size
                var overThresholdCount = 0

                for (index, asset) in assets.enumerated() {
                    if Task.isCancelled {
                        continuation.yield(.cancelled)
                        continuation.finish()
                        return
                    }

                    let metadata = asset.resourceMetadata()
                    reviewAssets.append(ReviewAsset(asset: asset, isCloudOnly: metadata.isCloudOnly, fileSize: metadata.fileSize))
                    let highlightBytes = asset.mediaType == .video
                        ? GeneralConstants.LargeFile.videoHighlightBytes
                        : GeneralConstants.LargeFile.photoHighlightBytes
                    if metadata.fileSize > highlightBytes {
                        overThresholdCount += 1
                    }

                    if (index + 1) % progressInterval == 0 || index == total - 1 {
                        continuation.yield(.progress(ProcessingProgress(current: index + 1, total: total, found: overThresholdCount)))
                    }
                }

                if Task.isCancelled {
                    continuation.yield(.cancelled)
                } else {
                    let sortedAssets = reviewAssets.sorted { $0.fileSize > $1.fileSize }
                    continuation.yield(.completed(sortedAssets))
                }
                continuation.finish()
            }
        }
    }

    func processAssetsForEyesClosed(
        _ assets: [PHAsset],
        progressInterval: Int = 5
    ) -> AsyncStream<ProcessingResult> {
        AsyncStream { continuation in
            Task {
                var blinkingAssets: [ReviewAsset] = []
                let total = assets.count
                let detector = await EyeBlinkDetector.shared.createReusableDetector()

                if detector == nil {
                    print("[PhotoProcessor] Warning: CIDetector creation failed, returning empty results")
                    continuation.yield(.completed([]))
                    continuation.finish()
                    return
                }

                for (index, asset) in assets.enumerated() {
                    if Task.isCancelled {
                        continuation.yield(.cancelled)
                        continuation.finish()
                        return
                    }

                    let isClosed = await EyeBlinkDetector.shared.hasClosedEyes(asset: asset, using: detector)

                    if isClosed {
                        let metadata = asset.resourceMetadata()
                        blinkingAssets.append(ReviewAsset(asset: asset, isCloudOnly: metadata.isCloudOnly, fileSize: metadata.fileSize))
                    }

                    if (index + 1) % progressInterval == 0 || index == total - 1 {
                        continuation.yield(.progress(ProcessingProgress(current: index + 1, total: total, found: blinkingAssets.count)))
                    }
                }

                if Task.isCancelled {
                    continuation.yield(.cancelled)
                } else {
                    continuation.yield(.completed(blinkingAssets))
                }
                continuation.finish()
            }
        }
    }
}

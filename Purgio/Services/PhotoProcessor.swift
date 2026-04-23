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
}

enum ProcessingResult {
    case progress(ProcessingProgress)
    case completed([ReviewAsset])
    case cancelled
}

actor PhotoProcessor {
    static let shared = PhotoProcessor()
    private init() {}

    func processAssets(
        _ assets: [PHAsset],
        progressInterval: Int = 1
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

                    reviewAssets.append(ReviewAsset(asset: asset, isCloudOnly: asset.isCloudOnly, fileSize: asset.fileSize))

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

                for (index, asset) in assets.enumerated() {
                    if Task.isCancelled {
                        continuation.yield(.cancelled)
                        continuation.finish()
                        return
                    }

                    reviewAssets.append(ReviewAsset(asset: asset, isCloudOnly: asset.isCloudOnly, fileSize: asset.fileSize))

                    if (index + 1) % progressInterval == 0 || index == total - 1 {
                        continuation.yield(.progress(ProcessingProgress(current: index + 1, total: total)))
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
                        blinkingAssets.append(ReviewAsset(asset: asset, isCloudOnly: asset.isCloudOnly, fileSize: asset.fileSize))
                    }

                    if (index + 1) % progressInterval == 0 || index == total - 1 {
                        continuation.yield(.progress(ProcessingProgress(current: index + 1, total: total)))
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

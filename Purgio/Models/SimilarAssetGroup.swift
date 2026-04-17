//
//  SimilarAssetGroup.swift
//  Purgio
//
//  Created by ZeynepMüslim on 11.01.2026.
//

import Photos

struct SimilarAssetGroup {
    let assets: [PHAsset]
    var bestAsset: PHAsset?
    let score: Float?

    init(assets: [PHAsset], bestAsset: PHAsset? = nil, score: Float? = nil) {
        self.assets = assets
        self.bestAsset = bestAsset ?? assets.first
        self.score = score
    }
}

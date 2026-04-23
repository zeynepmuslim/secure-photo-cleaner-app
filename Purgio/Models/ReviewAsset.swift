//
//  ReviewAsset.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.01.2026.
//

import Photos

struct ReviewAsset {
    let asset: PHAsset
    let isCloudOnly: Bool
    let fileSize: Int64

    var localIdentifier: String { asset.localIdentifier }
}

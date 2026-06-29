//
//  PHAsset+Metadata.swift
//  Purgio
//
//  Created by ZeynepMüslim on 16.03.2026.
//

import Photos

extension PHAsset {
    /// File size in bytes returns 0 if unavailable.
    var fileSize: Int64 {
        resourceMetadata().fileSize
    }

    /// True if asset requires network download (all resources are iCloud-only).
    var isCloudOnly: Bool {
        resourceMetadata().isCloudOnly
    }

    /// Fetches PHAssetResource list once and extracts both fileSize and isCloudOnly.
    /// Call this instead of accessing fileSize and isCloudOnly separately to avoid
    /// two PHAssetResource.assetResources calls per asset.
    func resourceMetadata() -> (fileSize: Int64, isCloudOnly: Bool) {
        let resources = PHAssetResource.assetResources(for: self)

        let size: Int64
        if let resource = resources.first, resource.responds(to: Selector(("fileSize"))) {
            size = resource.value(forKey: "fileSize") as? Int64 ?? 0
        } else {
            size = 0
        }

        let cloudOnly: Bool
        if resources.isEmpty {
            cloudOnly = false
        } else {
            cloudOnly = resources.allSatisfy { resource in
                guard resource.responds(to: Selector(("locallyAvailable"))),
                      let locallyAvailable = resource.value(forKey: "locallyAvailable") as? Bool
                else { return false }
                return !locallyAvailable
            }
        }

        return (fileSize: size, isCloudOnly: cloudOnly)
    }
}

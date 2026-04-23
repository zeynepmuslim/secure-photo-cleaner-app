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
        let resources = PHAssetResource.assetResources(for: self)
        guard let resource = resources.first,
              resource.responds(to: Selector(("fileSize")))
        else { return 0 }
        return resource.value(forKey: "fileSize") as? Int64 ?? 0
    }

    /// True if asset requires network download (all resources are iCloud-only).
    /// returns false if unavailable.
    var isCloudOnly: Bool {
        let resources = PHAssetResource.assetResources(for: self)
        guard !resources.isEmpty else { return false }

        for resource in resources {
            guard resource.responds(to: Selector(("locallyAvailable"))) else {
                return false
            }
            if let locallyAvailable = resource.value(forKey: "locallyAvailable") as? Bool {
                if locallyAvailable {
                    return false
                }
            } else {
                return false
            }
        }
        return true
    }
}

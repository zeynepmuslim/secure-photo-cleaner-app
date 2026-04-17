//
//  SessionKey.swift
//  Purgio
//
//  Created by ZeynepMüslim on 20.01.2026.
//

import Foundation

struct SessionKey: Codable, Hashable, Identifiable {
    let monthKey: String
    let mediaType: String   // PHAssetMediaType

    var id: String {
        return "\(monthKey)_\(mediaType)"
    }

    var undoKeyString: String {
        return id
    }
}

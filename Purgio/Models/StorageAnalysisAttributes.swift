//
//  StorageAnalysisAttributes.swift
//  Purgio
//
//  Created by ZeynepMüslim on 31.01.2026.
//

import Foundation
import ActivityKit

struct StorageAnalysisAttributes: ActivityAttributes {

    enum AnalysisPhase: String, Codable, Hashable {
        case photos
        case videos
        case complete
    }

    public struct ContentState: Codable, Hashable {
        var analyzedCount: Int
        var totalCount: Int
        var phase: AnalysisPhase
        var statusMessage: String
        var progress: Double
        var bytesAnalyzed: Int64
    }

    var startTime: Date
    
    var sessionId: String
}

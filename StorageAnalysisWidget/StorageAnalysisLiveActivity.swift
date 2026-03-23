//
//  StorageAnalysisLiveActivity.swift
//  StorageAnalysisWidget
//
//  Created by ZeynepMüslim on 31.01.2026.
//

import ActivityKit
import Foundation
import SwiftUI
import WidgetKit

extension Int64 {
    fileprivate func formattedBytes(allowedUnits: ByteCountFormatter.Units = [.useKB, .useMB, .useGB]) -> String {
        let formatter = Self.byteFormatter
        formatter.allowedUnits = allowedUnits
        return formatter.string(fromByteCount: self)
    }

    fileprivate static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

@available(iOS 16.1, *)
struct StorageAnalysisLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StorageAnalysisAttributes.self) { context in
            StorageAnalysisLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.stack.fill")
                                    .foregroundColor(.green)
                                Text("Storage")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }

                            Spacer()

                            Text("\(Int(context.state.progress * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }

                        Text(context.state.statusMessage)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ProgressView(value: context.state.progress)
                            .progressViewStyle(.linear)
                            .tint(.green)

                        HStack {
                            Text(context.state.bytesAnalyzed.formattedBytes())
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Spacer()

                            Text("\(context.state.analyzedCount) / \(context.state.totalCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(8)
                }

            } compactLeading: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "photo.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(width: 24, height: 24)
                .padding(.trailing, 1)

            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()

            } minimal: {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: context.state.progress)
                        .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "photo.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(width: 24, height: 24)
            }
        }
    }

}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct StorageAnalysisLockScreenView: View {
    let context: ActivityViewContext<StorageAnalysisAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "photo.stack.fill")
                    .font(.title3)
                    .foregroundColor(.green)

                Text("Storage Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(Int(context.state.progress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }

            ProgressView(value: context.state.progress)
                .progressViewStyle(.linear)
                .tint(.green)
                .scaleEffect(y: 1.5)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.state.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Text(phaseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(context.state.bytesAnalyzed.formattedBytes())
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("analyzed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(.background)
    }

    private var phaseDescription: String {
        switch context.state.phase {
        case .photos:
            return "Scanning photo library..."
        case .videos:
            return "Scanning video library..."
        case .complete:
            return "Analysis complete"
        }
    }

}

// MARK: - Preview

#if DEBUG

    @available(iOS 16.1, *)
    private let previewAttributes = StorageAnalysisAttributes(
        startTime: Date(),
        sessionId: "preview-session"
    )

    @available(iOS 16.1, *)
    private let startingState = StorageAnalysisAttributes.ContentState(
        analyzedCount: 0,
        totalCount: 5000,
        phase: .photos,
        statusMessage: "Starting analysis...",
        progress: 0.0,
        bytesAnalyzed: 0
    )

    @available(iOS 16.1, *)
    private let photosProgressState = StorageAnalysisAttributes.ContentState(
        analyzedCount: 1250,
        totalCount: 5000,
        phase: .photos,
        statusMessage: "Analyzing photos... (1250/5000)",
        progress: 0.25,
        bytesAnalyzed: 2_500_000_000
    )

    @available(iOS 16.1, *)
    private let videosProgressState = StorageAnalysisAttributes.ContentState(
        analyzedCount: 4500,
        totalCount: 5000,
        phase: .videos,
        statusMessage: "Analyzing videos... (500/1000)",
        progress: 0.80,
        bytesAnalyzed: 15_000_000_000
    )

    @available(iOS 16.1, *)
    private let completeState = StorageAnalysisAttributes.ContentState(
        analyzedCount: 5000,
        totalCount: 5000,
        phase: .complete,
        statusMessage: "Analysis complete ✓",
        progress: 1.0,
        bytesAnalyzed: 18_500_000_000
    )

    @available(iOS 17.0, *)
    #Preview("Lock Screen - Starting", as: .content, using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        startingState
    }

    @available(iOS 17.0, *)
    #Preview("Lock Screen - Photos 25%", as: .content, using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        photosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Lock Screen - Videos 80%", as: .content, using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        videosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Lock Screen - Complete", as: .content, using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        completeState
    }

    @available(iOS 17.0, *)
    #Preview("Compact - 25%", as: .dynamicIsland(.compact), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        photosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Compact - 80%", as: .dynamicIsland(.compact), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        videosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Compact - Complete", as: .dynamicIsland(.compact), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        completeState
    }

    @available(iOS 17.0, *)
    #Preview("Expanded - 25%", as: .dynamicIsland(.expanded), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        photosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Expanded - 80%", as: .dynamicIsland(.expanded), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        videosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Minimal - 25%", as: .dynamicIsland(.minimal), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        photosProgressState
    }

    @available(iOS 17.0, *)
    #Preview("Minimal - 80%", as: .dynamicIsland(.minimal), using: previewAttributes) {
        StorageAnalysisLiveActivity()
    } contentStates: {
        videosProgressState
    }

#endif

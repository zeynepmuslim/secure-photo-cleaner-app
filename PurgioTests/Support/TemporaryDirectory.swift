//
//  TemporaryDirectory.swift
//  PurgioTests
//

import Foundation

/// A unique, empty directory under `NSTemporaryDirectory()`, removed when the value is released.
/// Hold one per test and hand `url` to a store's test init.
final class TemporaryDirectory {
    let url: URL

    init() {
        url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("PurgioTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }

    /// A file URL inside the directory.
    func file(_ name: String) -> URL {
        url.appendingPathComponent(name)
    }
}

//
//  TestDefaults.swift
//  PurgioTests
//

import Foundation

/// An isolated `UserDefaults` suite for one test, removed when the value is released.
/// Hand `defaults` to a store's `init(defaults:)`; `.standard` is never touched.
final class TestDefaults {
    let suiteName: String
    let defaults: UserDefaults

    init() {
        suiteName = "PurgioTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("UserDefaults(suiteName:) returned nil for \(suiteName)")
        }
        self.defaults = defaults
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

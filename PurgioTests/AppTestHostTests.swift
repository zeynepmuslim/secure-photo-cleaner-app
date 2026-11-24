//
//  AppTestHostTests.swift
//  PurgioTests
//
//  Smoke tests for the hosted test bundle and the shared test helpers.
//

import Foundation
import Testing
import UIKit
@testable import Purgio

@Suite("App test host")
struct AppTestHostTests {

    @Test func theAppSkipsItsNormalLaunchUnderTests() {
        #expect(AppDelegate.isRunningUnitTests)
        #expect(!UITestingLaunchMode.isActive)
    }

    @MainActor
    @Test func theSceneMakesNoWindowUnderTests() {
        let sceneDelegates = UIApplication.shared.connectedScenes.compactMap { $0.delegate as? SceneDelegate }
        #expect(sceneDelegates.allSatisfy { $0.window == nil })
    }

    @Test func seededGeneratorRepeatsItsSequence() {
        var first = SeededGenerator(seed: 42)
        var second = SeededGenerator(seed: 42)
        var other = SeededGenerator(seed: 7)
        let a = (0..<5).map { _ in first.next() }
        let b = (0..<5).map { _ in second.next() }
        let c = (0..<5).map { _ in other.next() }
        #expect(a == b)
        #expect(a != c)
    }

    @Test func temporaryDirectoryIsRemovedWhenReleased() throws {
        var directory: TemporaryDirectory? = TemporaryDirectory()
        let url = try #require(directory?.url)
        try Data("x".utf8).write(to: url.appendingPathComponent("file.json"))
        #expect(FileManager.default.fileExists(atPath: url.path))
        directory = nil
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func testDefaultsAreIsolatedFromStandard() {
        let testDefaults = TestDefaults()
        let key = "purgioTests.isolationProbe"
        testDefaults.defaults.set(true, forKey: key)
        #expect(testDefaults.defaults.bool(forKey: key))
        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }
}

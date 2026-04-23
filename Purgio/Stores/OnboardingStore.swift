//
//  OnboardingStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 22.04.2026.
//

import Foundation

final class OnboardingStore {
    static let shared = OnboardingStore()

    private let defaults = UserDefaults.standard
    private let hasCompletedKey = "hasCompletedOnboarding"

    private init() {}

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: hasCompletedKey) }
        set { defaults.set(newValue, forKey: hasCompletedKey) }
    }
}

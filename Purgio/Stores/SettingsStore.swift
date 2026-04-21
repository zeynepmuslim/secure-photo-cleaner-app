//
//  SettingsStore.swift
//  Purgio
//
//  Created by ZeynepMüslim on 4.01.2026.
//

import Foundation

final class SettingsStore {
    static let shared = SettingsStore()
    
    private let defaults = UserDefaults.standard
    private let internetAccessKey = "allowInternetAccess"
    private let internetOverrideActiveKey = "internetOverrideActive"
    private let skipICloudPhotosKey = "skipICloudPhotos"
    private let hasShownInitialICloudWarningKey = "hasShownInitialICloudWarning"
    private let hasShownPerCardICloudWarningKey = "hasShownPerCardICloudWarning"
    private let hasShownStoreTutorialKey = "hasShownStoreTutorial"
    private let remindersEnabledKey = "remindersEnabled"
    private let reminderHourKey = "reminderHour"
    private let reminderMinuteKey = "reminderMinute"
    private let reminderFrequencyKey = "reminderFrequency"
    private let reminderWeekdaysKey = "reminderWeekdays"
    private let reminderMonthDayKey = "reminderMonthDay"

    private init() {}
    
    var allowInternetAccess: Bool {
        get {
            defaults.bool(forKey: internetAccessKey)
        }
        set {
            let oldValue = defaults.bool(forKey: internetAccessKey)
            defaults.set(newValue, forKey: internetAccessKey)

            if oldValue != newValue {
                iCloudSyncLogger.shared.logNetworkAccessChanged(allowed: newValue, source: "user_settings")
            }
        }
    }

    // Note for devs:
    // StoreKit product fetches and purchases go through Apple's system process and are unaffected by our `allowInternetAccess` flag. this gate is purely a UX/privacy courtesy.
    // We ask the user to opt in because processing a tip while they have explicitly disabled network access would feel dishonest, even though no app-originated network call is actually involved.
    func beginTemporaryInternetOverride() {
        defaults.set(true, forKey: internetOverrideActiveKey)
        allowInternetAccess = true
    }

    func endTemporaryInternetOverride() {
        guard defaults.bool(forKey: internetOverrideActiveKey) else { return }
        defaults.removeObject(forKey: internetOverrideActiveKey)
        allowInternetAccess = false
    }

    var skipICloudPhotos: Bool {
        get {
            defaults.bool(forKey: skipICloudPhotosKey)
        }
        set {
            defaults.set(newValue, forKey: skipICloudPhotosKey)
        }
    }

    // MARK: - iCloud Warning Display Tracking

    /// Dev mode: Set to true to always show iCloud warnings (for testing)
    var alwaysShowICloudWarnings: Bool = false

    /// Returns true if the initial iCloud warning has been shown (persisted)
    var hasShownInitialICloudWarning: Bool {
        get {
            if alwaysShowICloudWarnings { return false }
            return defaults.bool(forKey: hasShownInitialICloudWarningKey)
        }
        set {
            defaults.set(newValue, forKey: hasShownInitialICloudWarningKey)
        }
    }

    /// Returns true if the per-card iCloud warning has been shown (persisted)
    var hasShownPerCardICloudWarning: Bool {
        get {
            if alwaysShowICloudWarnings { return false }
            return defaults.bool(forKey: hasShownPerCardICloudWarningKey)
        }
        set {
            defaults.set(newValue, forKey: hasShownPerCardICloudWarningKey)
        }
    }

    func resetICloudWarningFlags() {
        defaults.removeObject(forKey: hasShownInitialICloudWarningKey)
        defaults.removeObject(forKey: hasShownPerCardICloudWarningKey)
    }

    var hasShownStoreTutorial: Bool {
        get { defaults.bool(forKey: hasShownStoreTutorialKey) }
        set { defaults.set(newValue, forKey: hasShownStoreTutorialKey) }
    }

    var remindersEnabled: Bool {
        get {
            defaults.bool(forKey: remindersEnabledKey)
        }
        set {
            defaults.set(newValue, forKey: remindersEnabledKey)
        }
    }

    var reminderHour: Int {
        get {
            if defaults.object(forKey: reminderHourKey) == nil {
                return 20
            }
            return defaults.integer(forKey: reminderHourKey)
        }
        set {
            defaults.set(min(max(newValue, 0), 23), forKey: reminderHourKey)
        }
    }

    var reminderMinute: Int {
        get {
            if defaults.object(forKey: reminderMinuteKey) == nil {
                return 0
            }
            return defaults.integer(forKey: reminderMinuteKey)
        }
        set {
            defaults.set(min(max(newValue, 0), 59), forKey: reminderMinuteKey)
        }
    }

    var reminderFrequency: ReminderFrequency {
        get {
            if let rawValue = defaults.string(forKey: reminderFrequencyKey),
               let value = ReminderFrequency(rawValue: rawValue) {
                return value
            }
            return .weekly
        }
        set {
            defaults.set(newValue.rawValue, forKey: reminderFrequencyKey)
        }
    }

    var reminderWeekdays: [Int] {
        get {
            if let saved = defaults.array(forKey: reminderWeekdaysKey) as? [Int], !saved.isEmpty {
                return saved
            }
            return [6] // Friday
        }
        set {
            let valid = Array(Set(newValue.filter { (1...7).contains($0) })).sorted()
            defaults.set(valid, forKey: reminderWeekdaysKey)
        }
    }

    var reminderMonthDay: Int {
        get {
            if defaults.object(forKey: reminderMonthDayKey) == nil {
                return 1
            }
            return defaults.integer(forKey: reminderMonthDayKey)
        }
        set {
            defaults.set(min(max(newValue, 1), 28), forKey: reminderMonthDayKey)
        }
    }

    enum ReminderSchedulePreset: String, CaseIterable {
        case dailyEvening
        case weeklyEvening
        case monthlyFirstEvening
    }

    func applyReminderSchedule(_ preset: ReminderSchedulePreset) {
        switch preset {
        case .dailyEvening:
            reminderFrequency = .daily
            reminderHour = 20
            reminderMinute = 0
            reminderWeekdays = []
            reminderMonthDay = 1
        case .weeklyEvening:
            reminderFrequency = .weekly
            reminderHour = 20
            reminderMinute = 0
            reminderWeekdays = [6] // Friday
            reminderMonthDay = 1
        case .monthlyFirstEvening:
            reminderFrequency = .monthly
            reminderHour = 20
            reminderMinute = 0
            reminderWeekdays = []
            reminderMonthDay = 1
        }
    }
}


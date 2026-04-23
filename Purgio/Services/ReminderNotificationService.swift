//
//  ReminderNotificationService.swift
//  Purgio
//
//  Created by ZeynepMüslim on 31.01.2026.
//

import Foundation
import UserNotifications

enum ReminderFrequency: String {
    case daily
    case weekly
    case monthly
}

extension Notification.Name {
    static let notificationDeepLinkToDeleteBin = Notification.Name("notificationDeepLinkToDeleteBin")
}

final class ReminderNotificationService: NSObject {
    static let shared = ReminderNotificationService()

    static let categoryIdentifier = "CLEANUP_REMINDER"
    static let actionCleanNow = "CLEAN_NOW_ACTION"
    static let actionSnooze = "SNOOZE_ACTION"
    private static let snoozeRequestId = "cleanupReminder.snooze"

    private let center = UNUserNotificationCenter.current()
    private let settingsStore = SettingsStore.shared
    private let dataCenter = ReminderDataCenter.shared

    #if DEBUG
        private let snoozeInterval: TimeInterval = 90   // 1.5 dakika
    #else
        private let snoozeInterval: TimeInterval = 3600   // 1 saat
    #endif

    private override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDataCenterChange),
            name: .reminderDataCenterDidChange,
            object: nil
        )
    }

    struct ReminderSchedule {
        let hour: Int
        let minute: Int
        let frequency: ReminderFrequency
        let weekdays: [Int]
        let monthDay: Int
    }

    private let fallbackMessages = [
        NSLocalizedString("notification.fallback1", comment: "Fallback notification: library cleanup"),
        NSLocalizedString("notification.fallback2", comment: "Fallback notification: tidy up"),
        NSLocalizedString("notification.fallback3", comment: "Fallback notification: free up space"),
        NSLocalizedString("notification.fallback4", comment: "Fallback notification: screenshots and duplicates"),
        NSLocalizedString("notification.fallback5", comment: "Fallback notification: review recent"),
        NSLocalizedString("notification.fallback6", comment: "Fallback notification: stay organized"),
        NSLocalizedString("notification.fallback7", comment: "Fallback notification: remove unneeded"),
        NSLocalizedString("notification.fallback8", comment: "Fallback notification: fresh start"),
    ]

    private let requestIdPrefix = "cleanupReminder"

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func syncScheduleIfNeeded() {
        if settingsStore.remindersEnabled {
            scheduleReminders()
        } else {
            removeScheduledReminders()
        }
    }

    func scheduleReminders() {
        removeScheduledReminders()
        dataCenter.markReminderScheduledNowForTesting()

        let schedule = ReminderSchedule(
            hour: settingsStore.reminderHour,
            minute: settingsStore.reminderMinute,
            frequency: settingsStore.reminderFrequency,
            weekdays: settingsStore.reminderWeekdays,
            monthDay: settingsStore.reminderMonthDay
        )

        var messages = dataCenter.notificationMessages(fallback: fallbackMessages)

        if let randomFallback = fallbackMessages.randomElement(),
            !messages.contains(randomFallback)
        {
            messages.append(randomFallback)
        }

        let randomMinute = Int.random(in: 0...59)

        switch schedule.frequency {
        case .daily:
            let message = messages.randomElement() ?? fallbackMessages[0]
            let content = makeContent(message: message)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: schedule.hour, minute: randomMinute),
                repeats: true
            )
            addRequest(idSuffix: "daily", content: content, trigger: trigger)
        case .weekly:
            let randomWeekday = Int.random(in: 1...7) // Sun–Sat
            let message = messages.randomElement() ?? fallbackMessages[0]
            let content = makeContent(message: message)
            var components = DateComponents()
            components.weekday = randomWeekday
            components.hour = schedule.hour
            components.minute = randomMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            addRequest(idSuffix: "weekly_\(randomWeekday)", content: content, trigger: trigger)
        case .monthly:
            let message = messages.randomElement() ?? fallbackMessages[0]
            let content = makeContent(message: message)
            var components = DateComponents()
            components.day = schedule.monthDay
            components.hour = schedule.hour
            components.minute = randomMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            addRequest(idSuffix: "monthly", content: content, trigger: trigger)
        }
    }

    private func makeContent(message: String) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification.title", comment: "Notification title for cleanup reminders")
        content.body = message
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        return content
    }

    private func addRequest(idSuffix: String, content: UNNotificationContent, trigger: UNNotificationTrigger) {
        let request = UNNotificationRequest(
            identifier: "\(requestIdPrefix).\(idSuffix)",
            content: content,
            trigger: trigger
        )
        center.add(request)
    }

    private func removeScheduledReminders() {
        center.getPendingNotificationRequests { [requestIdPrefix] requests in
            let identifiers =
                requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(requestIdPrefix) }
            if !identifiers.isEmpty {
                self.center.removePendingNotificationRequests(withIdentifiers: identifiers)
            }
        }
    }

    func debugPrintSampleReminders() {
        let generated = dataCenter.notificationMessages(fallback: fallbackMessages)
        print("[ReminderDebug] Generated reminders:")
        for message in generated {
            print("[ReminderDebug] - \(message)")
        }
        let examples = dataCenter.exampleMessagesForAllSignals()
        print("[ReminderDebug] Example reminders:")
        for message in examples {
            print("[ReminderDebug] - \(message)")
        }
    }

    @objc private func handleDataCenterChange() {
        guard settingsStore.remindersEnabled else { return }
        scheduleReminders()
    }

    func registerCategories() {
        let cleanNowAction = UNNotificationAction(
            identifier: Self.actionCleanNow,
            title: NSLocalizedString("notification.cleanNow", comment: "Clean now notification action"),
            options: .foreground
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.actionSnooze,
            title: NSLocalizedString("notification.snooze", comment: "Snooze notification action"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [cleanNowAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    private func scheduleSnooze() {
        let messages = dataCenter.notificationMessages(fallback: fallbackMessages)
        let message = messages.randomElement() ?? fallbackMessages[0]
        let content = makeContent(message: message)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.snoozeRequestId,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

// MARK: - Debug Helpers

#if DEBUG
    extension ReminderNotificationService {
        private static let testRequestId = "cleanupReminder.test"

        func scheduleTestNotification(afterSeconds seconds: TimeInterval = 5) {
            let messages = dataCenter.notificationMessages(fallback: fallbackMessages)
            let message = messages.randomElement() ?? fallbackMessages[0]
            let content = makeContent(message: message)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
            let request = UNNotificationRequest(
                identifier: Self.testRequestId,
                content: content,
                trigger: trigger
            )
            center.removePendingNotificationRequests(withIdentifiers: [Self.testRequestId])
            center.add(request)
        }

        func getPendingCount(completion: @escaping (Int) -> Void) {
            center.getPendingNotificationRequests { requests in
                let count = requests.filter { $0.identifier.hasPrefix(self.requestIdPrefix) }.count
                DispatchQueue.main.async { completion(count) }
            }
        }
    }
#endif

// MARK: - UNUserNotificationCenterDelegate

extension ReminderNotificationService: UNUserNotificationCenterDelegate {

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        guard identifier.hasPrefix(requestIdPrefix) else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case Self.actionSnooze:
            scheduleSnooze()
            completionHandler()
            return

        case UNNotificationDefaultActionIdentifier, Self.actionCleanNow:
            dataCenter.recordReminderOpened()
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .notificationDeepLinkToDeleteBin, object: nil)
            }
            completionHandler()

        default:
            completionHandler()
        }
    }
}

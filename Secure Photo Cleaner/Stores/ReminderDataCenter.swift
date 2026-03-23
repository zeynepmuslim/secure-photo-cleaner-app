//
//  ReminderDataCenter.swift
//  Secure Photo Cleaner
//
//  Created by ZeynepMüslim on 25.01.2026.
//

import Foundation
import Photos

final class ReminderDataCenter {
    static let shared = ReminderDataCenter()

    private let storageQueue = DispatchQueue(label: "com.galary.ReminderDataCenter.storage")
    private let fileURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("SecurePhotoCleaner/reminderData.json")
    }()

    private struct ReminderData: Codable {
        var lastCleanDate: Date? = nil
        var lastCleanedCount: Int = 0
        var lastCleanedBytes: Int64 = 0
        var lastReviewDate: Date? = nil
        var lastReviewMediaTypeRaw: String? = nil
        var lastReviewStreakDays: Int = 0
        var lastReviewStreakDate: Date? = nil
        var lastReviewMonthKey: String? = nil
        var reviewProgressByMonth: [String: Double] = [:]
        var lastSimilarReviewDate: Date? = nil
        var lastReminderSentAt: Date? = nil
        var reminderOpenCount: Int = 0
        var lastPotentialSavingsBytes: Int64 = 0
        var lastStorageSavedBytes: Int64 = 0
    }

    private var data = ReminderData()
    private var persistWorkItem: DispatchWorkItem?
    private var notifyWorkItem: DispatchWorkItem?

    private init() {
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)

        if let fileData = try? Data(contentsOf: fileURL),
            let decoded = try? JSONDecoder().decode(ReminderData.self, from: fileData)
        {
            data = decoded
        }
    }

    private func persistToDisk() {
        persistWorkItem?.cancel()
        let snapshot = data
        let url = fileURL
        let item = DispatchWorkItem {
            if let fileData = try? JSONEncoder().encode(snapshot) {
                try? fileData.write(to: url, options: [.atomic])
            }
        }
        persistWorkItem = item
        storageQueue.asyncAfter(deadline: .now() + 0.3, execute: item)
    }

    var lastCleanDate: Date? {
        get { data.lastCleanDate }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastCleanDate else { return }
            data.lastCleanDate = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastCleanedCount: Int {
        get { data.lastCleanedCount }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastCleanedCount else { return }
            data.lastCleanedCount = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastCleanedBytes: Int64 {
        get { data.lastCleanedBytes }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastCleanedBytes else { return }
            data.lastCleanedBytes = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastReviewDate: Date? {
        get { data.lastReviewDate }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastReviewDate else { return }
            data.lastReviewDate = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastReviewMediaType: PHAssetMediaType? {
        get {
            guard let raw = data.lastReviewMediaTypeRaw else { return nil }
            return raw == "video" ? .video : .image
        }
        set {
            assert(Thread.isMainThread)
            let raw = newValue.map { $0 == .video ? "video" : "image" }
            guard raw != data.lastReviewMediaTypeRaw else { return }
            data.lastReviewMediaTypeRaw = raw
            persistToDisk()
            notifyChange()
        }
    }

    var lastReviewStreakDays: Int {
        get { max(0, data.lastReviewStreakDays) }
        set {
            assert(Thread.isMainThread)
            let clamped = max(0, newValue)
            guard clamped != data.lastReviewStreakDays else { return }
            data.lastReviewStreakDays = clamped
            persistToDisk()
            notifyChange()
        }
    }

    var lastReviewMonthKey: String? {
        get { data.lastReviewMonthKey }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastReviewMonthKey else { return }
            data.lastReviewMonthKey = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var reviewProgressByMonth: [String: Double] {
        get { data.reviewProgressByMonth }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.reviewProgressByMonth else { return }
            data.reviewProgressByMonth = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastSimilarReviewDate: Date? {
        get { data.lastSimilarReviewDate }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastSimilarReviewDate else { return }
            data.lastSimilarReviewDate = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastReminderSentAt: Date? {
        get { data.lastReminderSentAt }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastReminderSentAt else { return }
            data.lastReminderSentAt = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var reminderOpenCount: Int {
        get { data.reminderOpenCount }
        set {
            assert(Thread.isMainThread)
            let clamped = max(0, newValue)
            guard clamped != data.reminderOpenCount else { return }
            data.reminderOpenCount = clamped
            persistToDisk()
            notifyChange()
        }
    }

    var lastPotentialSavingsBytes: Int64 {
        get { data.lastPotentialSavingsBytes }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastPotentialSavingsBytes else { return }
            data.lastPotentialSavingsBytes = newValue
            persistToDisk()
            notifyChange()
        }
    }

    var lastStorageSavedBytes: Int64 {
        get { data.lastStorageSavedBytes }
        set {
            assert(Thread.isMainThread)
            guard newValue != data.lastStorageSavedBytes else { return }
            data.lastStorageSavedBytes = newValue
            persistToDisk()
            notifyChange()
        }
    }

    func markCleanedNow(count: Int, cleanedBytes: Int64 = 0, potentialSavingsBytes: Int64 = 0, savedBytes: Int64 = 0) {
        assert(Thread.isMainThread)
        data.lastCleanDate = Date()
        data.lastCleanedCount = count
        data.lastCleanedBytes = cleanedBytes
        data.lastPotentialSavingsBytes = potentialSavingsBytes
        data.lastStorageSavedBytes = savedBytes
        persistToDisk()
        notifyChange()
    }

    func markMonthReviewed(_ monthKey: String, mediaType: PHAssetMediaType) {
        assert(Thread.isMainThread)
        data.lastReviewMonthKey = monthKey
        data.lastReviewMediaTypeRaw = mediaType == .video ? "video" : "image"
        data.lastReviewDate = Date()
        updateReviewStreakInternal()
        persistToDisk()
        notifyChange()
    }

    func markReviewActivity(monthKey: String, mediaType: PHAssetMediaType, reviewedCount: Int, totalCount: Int) {
        assert(Thread.isMainThread)
        data.lastReviewMonthKey = monthKey
        data.lastReviewMediaTypeRaw = mediaType == .video ? "video" : "image"
        data.lastReviewDate = Date()
        updateReviewStreakInternal()
        updateReviewProgressInternal(monthKey: monthKey, reviewedCount: reviewedCount, totalCount: totalCount)
        persistToDisk()
        notifyChange()
    }

    func markSimilarReviewActivity(monthKey: String, mediaType: PHAssetMediaType, reviewedCount: Int, totalCount: Int) {
        assert(Thread.isMainThread)
        data.lastSimilarReviewDate = Date()
        data.lastReviewMonthKey = monthKey
        data.lastReviewMediaTypeRaw = mediaType == .video ? "video" : "image"
        data.lastReviewDate = Date()
        updateReviewStreakInternal()
        updateReviewProgressInternal(monthKey: monthKey, reviewedCount: reviewedCount, totalCount: totalCount)
        persistToDisk()
        notifyChange()
    }

    func updateReviewProgress(monthKey: String, reviewedCount: Int, totalCount: Int) {
        assert(Thread.isMainThread)
        guard totalCount > 0 else { return }
        let progress = min(1.0, max(0.0, Double(reviewedCount) / Double(totalCount)))
        guard data.reviewProgressByMonth[monthKey] != progress else { return }
        data.reviewProgressByMonth[monthKey] = progress
        persistToDisk()
        notifyChange()
    }

    func markReminderScheduledNowForTesting() {
        data.lastReminderSentAt = Date()
    }

    func recordReminderOpened() {
        assert(Thread.isMainThread)
        reminderOpenCount += 1
    }

    func notificationMessages(fallback: [String]) -> [String] {
        var messages: [String] = []

        // Signal 1: 30+ days since last clean
        if let lastCleanDate = lastCleanDate,
            let days = daysSince(date: lastCleanDate),
            days >= 30
        {
            let options = [
                "It's been over a month since your last cleanup. Time for a fresh start!",
                "Your photos have been piling up for a month. Let's tidy up!",
                "A month without cleaning? Your library deserves some love."
            ]
            messages.append(options.randomElement()!)
        }

        // Signal 2: Bin has items
        let binCount = DeleteBinStore.shared.count
        if binCount > 0 {
            let count = binCount
            let s = count == 1 ? "" : "s"
            let options = [
                "Your Delete Bin has \(count) item\(s). Clear it now to free up space!",
                "\(count) item\(s) waiting in your bin. Tap to clean up!",
                "You've got \(count) item\(s) ready to delete. Finish the job!"
            ]
            messages.append(options.randomElement()!)
        }

        // Signal 3: Last cleaned count
        if lastCleanedCount > 0 {
            let s = lastCleanedCount == 1 ? "" : "s"
            messages.append("Last time you cleaned \(lastCleanedCount) item\(s) — ready to beat that?")
        }

        // Signal 4: Last cleaned bytes
        if lastCleanedBytes > 0 {
            let formatted = lastCleanedBytes.formattedBytes(allowedUnits: [.useMB, .useGB])
            messages.append("You freed \(formatted) last time. Ready for another round?")
        }

        // Signal 5: Potential savings
        if lastPotentialSavingsBytes > 0 {
            let formatted = lastPotentialSavingsBytes.formattedBytes(allowedUnits: [.useMB, .useGB])
            messages.append("You could free up \(formatted) right now. Just a few taps!")
        }

        // Signal 6: Storage saved last time
        if lastStorageSavedBytes > 0 {
            let formatted = lastStorageSavedBytes.formattedBytes(allowedUnits: [.useMB, .useGB])
            messages.append("You saved \(formatted) last time. Want more free space?")
        }

        // Signal 7: 7+ days inactive
        if let lastReviewDate = lastReviewDate,
            let days = daysSince(date: lastReviewDate),
            days >= 7
        {
            messages.append("It's been \(days) days since your last review. Your photos miss you!")
        }

        // Signal 8: In-progress month
        if let monthKey = lastReviewMonthKey,
            let progress = reviewProgressByMonth[monthKey],
            progress > 0.0, progress < 1.0
        {
            let percent = Int(progress * 100)
            let displayMonth = formattedMonthName(monthKey)
            messages.append("Almost there! You're \(percent)% through \(displayMonth).")
        }

        // Signal 9: Review streak
        if lastReviewStreakDays >= 3 {
            messages.append("You're on a \(lastReviewStreakDays)-day review streak. Keep it going!")
        }

        // Signal 10: Similar photos overdue
        if let lastSimilarReviewDate = lastSimilarReviewDate,
            let days = daysSince(date: lastSimilarReviewDate),
            days >= 14
        {
            messages.append("Similar photos are waiting. Clean duplicates in minutes.")
        }

        // Motivational signals from all-time stats
        let stats = StatsStore.shared

        if stats.spaceSavedBytes > 0 {
            let formatted = stats.spaceSavedBytes.formattedBytes(allowedUnits: [.useMB, .useGB])
            messages.append("You've saved \(formatted) so far. Keep your library clean!")
        }

        if stats.totalDeleted > 0 {
            messages.append("You've cleaned \(stats.totalDeleted) photos so far. Nice work!")
        }

        if stats.totalReviewed >= 50 {
            messages.append("You've reviewed \(stats.totalReviewed) photos. Keep the momentum!")
        }

        if messages.isEmpty {
            return fallback
        }

        return messages.shuffled()
    }

    func exampleMessagesForAllSignals() -> [String] {   // onşy investigate the possibale messages, just for print
        return [
            "It's been over a month since your last cleanup. Time for a fresh start!",
            "Your Delete Bin has 42 items. Clear it now to free up space!",
            "Last time you cleaned 120 items — ready to beat that?",
            "You freed 1.2 GB last time. Ready for another round?",
            "You could free up 500 MB right now. Just a few taps!",
            "It's been 12 days since your last review. Your photos miss you!",
            "Almost there! You're 65% through January 2024.",
            "You're on a 5-day review streak. Keep it going!",
            "Similar photos are waiting. Clean duplicates in minutes.",
            "You've saved 2.5 GB so far. Keep your library clean!",
            "You've cleaned 350 photos so far. Nice work!",
            "You've reviewed 1200 photos. Keep the momentum!"
        ]
    }

    private func updateReviewStreakInternal() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let lastDate = data.lastReviewStreakDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if lastDay == today { return }
            if let days = calendar.dateComponents([.day], from: lastDay, to: today).day, days == 1 {
                data.lastReviewStreakDays = max(0, data.lastReviewStreakDays + 1)
            } else {
                data.lastReviewStreakDays = 1
            }
        } else {
            data.lastReviewStreakDays = 1
        }
        data.lastReviewStreakDate = today
    }

    private func updateReviewProgressInternal(monthKey: String, reviewedCount: Int, totalCount: Int) {
        guard totalCount > 0 else { return }
        let progress = min(1.0, max(0.0, Double(reviewedCount) / Double(totalCount)))
        data.reviewProgressByMonth[monthKey] = progress
    }

    private func daysSince(date: Date) -> Int? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: Date())
        return calendar.dateComponents([.day], from: start, to: end).day
    }

    private static let monthInputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()

    private static let monthOutputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private func formattedMonthName(_ monthKey: String) -> String {
        guard let date = Self.monthInputFormatter.date(from: monthKey) else { return monthKey }
        return Self.monthOutputFormatter.string(from: date)
    }

    private func notifyChange() {
        notifyWorkItem?.cancel()
        let item = DispatchWorkItem {
            NotificationCenter.default.post(name: .reminderDataCenterDidChange, object: nil)
        }
        notifyWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
}

extension Notification.Name {
    static let reminderDataCenterDidChange = Notification.Name("reminderDataCenterDidChange")
}

//
//  DateFormatterManager.swift
//  Purgio
//
//  Created by ZeynepMüslim on 23.01.2026.
//

import Foundation

final class DateFormatterManager {
    static let shared = DateFormatterManager()

    private init() {}

    private lazy var monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    /// January 2026
    private lazy var monthDisplayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// 01.2026
    private lazy var monthShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM.yyyy"
        return formatter
    }()

    /// Time only formatter with short style
    private lazy var timeShortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    /// Date only formatter with medium style
    private lazy var dateMediumFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - Month Key Operations

    func date(fromMonthKey monthKey: String) -> Date? {
        return monthKeyFormatter.date(from: monthKey)
    }

    func monthKey(from date: Date) -> String {
        return monthKeyFormatter.string(from: date)
    }

    // MARK: - Display Formatting

    /// 2026-01 → January 2026
    func displayMonth(fromMonthKey monthKey: String) -> String {
        guard let date = date(fromMonthKey: monthKey) else { return monthKey }
        return monthDisplayFormatter.string(from: date)
    }

    /// 2026-01 → 01.2026
    func shortMonth(fromMonthKey monthKey: String) -> String {
        guard let date = date(fromMonthKey: monthKey) else { return monthKey }
        return monthShortFormatter.string(from: date)
    }

    /// Format a Date to full month display string (e.g., "January 2026
    func displayMonth(from date: Date) -> String {
        return monthDisplayFormatter.string(from: date)
    }

    /// Format time from hour and minute components (e.g., "9:30 AM")
    func shortTime(hour: Int, minute: Int) -> String {
        let components = DateComponents(hour: hour, minute: minute)
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        return timeShortFormatter.string(from: date)
    }

    /// Format a Date to short time string
    func shortTime(from date: Date) -> String {
        return timeShortFormatter.string(from: date)
    }

    /// Jan 31, 2026
    func mediumDate(from date: Date) -> String {
        return dateMediumFormatter.string(from: date)
    }

    // MARK: - Video Duration
    private lazy var videoDurationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    /// Format seconds to m:ss (e.g., 63.0 → "1:03")
    func formatVideoDuration(_ seconds: Double) -> String {
        videoDurationFormatter.string(from: seconds) ?? "0:00"
    }

    /// "2025-01" → "01-2025"
    func compactMonth(fromMonthKey monthKey: String) -> String? {
        guard let date = date(fromMonthKey: monthKey) else { return nil }
        let comps = Calendar.current.dateComponents([.year, .month], from: date)
        guard let year = comps.year, let month = comps.month else { return nil }
        return String(format: "%02d-%d", month, year)
    }

    /// Get the start and end dates for a month key
    func monthDateRange(forMonthKey monthKey: String) -> (start: Date, end: Date)? {
        let calendar = Calendar.current
        guard let date = date(fromMonthKey: monthKey),
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
            let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else {
            return nil
        }
        return (monthStart, monthEnd)
    }
}

import Foundation

/// 日付は日本時間でそろえる（締め切りも「今日」も日本の暦）。
enum JapanDate {
    static let timeZone = TimeZone(identifier: "Asia/Tokyo") ?? .current

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    /// "2026-11-14" → その日の 0 時
    static func date(day: String?) -> Date? {
        guard let day else { return nil }
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func dayString(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func weekdaySymbol(_ date: Date) -> String {
        let index = calendar.component(.weekday, from: date) - 1
        return ["日", "月", "火", "水", "木", "金", "土"][index]
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func addingDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: startOfDay(date)) ?? date
    }

    /// その日を含む週（日曜はじまり）の7日
    static func week(containing date: Date) -> [Date] {
        let start = startOfDay(date)
        let weekday = calendar.component(.weekday, from: start)
        let sunday = addingDays(-(weekday - 1), to: start)
        return (0..<7).map { addingDays($0, to: sunday) }
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}

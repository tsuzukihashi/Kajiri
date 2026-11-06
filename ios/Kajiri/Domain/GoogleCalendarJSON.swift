import Foundation

/// Google カレンダーの API の答え。使う欄だけを読む
struct GoogleCalendarList: Decodable, Sendable {
    let items: [GoogleCalendarEntry]?
    let nextPageToken: String?
}

struct GoogleCalendarEntry: Decodable, Sendable, Equatable {
    let id: String
    let summary: String?
    /// 本人が名前を付け直しているとき
    let summaryOverride: String?
    /// 例: "#9fc6e7"
    let backgroundColor: String?
    /// Google カレンダーの画面で表示をオンにしているか
    let selected: Bool?
    let hidden: Bool?

    /// 本人が Google カレンダーで見ているものだけを読む
    var isShown: Bool { selected == true && hidden != true }
    var title: String { summaryOverride ?? summary ?? "" }
}

struct GoogleEventList: Decodable, Sendable {
    let items: [GoogleEventItem]?
    let nextPageToken: String?
}

struct GoogleEventItem: Decodable, Sendable {
    struct Moment: Decodable, Sendable {
        /// 終日の予定: "2026-11-20"
        let date: String?
        /// 時刻のある予定: "2026-11-20T10:00:00+09:00"
        let dateTime: String?
    }

    let id: String
    let status: String?
    let summary: String?
    let location: String?
    let start: Moment?
    let end: Moment?
    let htmlLink: String?
    let recurringEventId: String?
}

enum GoogleEventMapper {
    /// 消された予定と、日時の読めない予定は並べない
    static func events(from list: GoogleEventList, calendar: GoogleCalendarEntry) -> [CalendarEvent] {
        (list.items ?? []).compactMap { event(from: $0, calendar: calendar) }
    }

    static func event(from item: GoogleEventItem, calendar: GoogleCalendarEntry) -> CalendarEvent? {
        guard item.status != "cancelled", let start = item.start, let end = item.end else { return nil }
        let isAllDay = start.date != nil
        guard let startDate = date(of: start), let endDate = date(of: end) else { return nil }
        let color = rgb(hex: calendar.backgroundColor)
        return CalendarEvent(
            id: "google|\(calendar.id)|\(item.id)",
            eventIdentifier: item.recurringEventId ?? item.id,
            title: item.summary ?? String(localized: "（名前のない予定）"),
            start: startDate,
            end: endDate,
            isAllDay: isAllDay,
            location: item.location ?? "",
            calendarTitle: calendar.title,
            red: color.red, green: color.green, blue: color.blue,
            source: .google(link: item.htmlLink.flatMap(URL.init(string:)))
        )
    }

    private static func date(of moment: GoogleEventItem.Moment) -> Date? {
        if let day = moment.date { return JapanDate.date(day: day) }
        guard let text = moment.dateTime else { return nil }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let found = plain.date(from: text) { return found }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    /// "#RRGGBB" → 0〜1。読めないときは灰色
    static func rgb(hex: String?) -> (red: Double, green: Double, blue: Double) {
        let gray = (red: 0.5, green: 0.5, blue: 0.5)
        guard let hex else { return gray }
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return gray }
        return (
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

/// iPhone のカレンダーと Google から読んだ予定を1つにまとめる。
/// iPhone の設定にも同じ Google アカウントを入れている人は、同じ予定が両方から来る。
/// 直せる iPhone 側を残す
enum CalendarMerger {
    static func merged(device: [CalendarEvent], google: [CalendarEvent]) -> [CalendarEvent] {
        let seen = Set(device.map(key))
        return device + google.filter { !seen.contains(key($0)) }
    }

    private static func key(_ event: CalendarEvent) -> String {
        if event.isAllDay { return "\(event.title)|\(JapanDate.dayString(event.start))|終日" }
        return "\(event.title)|\(Int(event.start.timeIntervalSince1970))|\(Int(event.end.timeIntervalSince1970))"
    }
}

import Foundation

/// どこから読んだ予定か
enum CalendarEventSource: Hashable, Sendable {
    /// iPhone のカレンダー（設定に入れた Google・iCloud・Outlook など）。Kajiri から直せる
    case device
    /// Kajiri でつないだ Google カレンダー。読むだけなので、直すのは Google 側で
    case google(link: URL?)
}

/// 予定1件
struct CalendarEvent: Identifiable, Hashable, Sendable {
    /// 予定1回ぶんの名前（くり返しの予定は、回ごとに別の id になる）
    let id: String
    /// EventKit の予定の名前（くり返しの予定は全部の回で同じ）
    let eventIdentifier: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String
    let calendarTitle: String
    /// カレンダーの色（0〜1 の赤・緑・青）
    let red: Double
    let green: Double
    let blue: Double
    let source: CalendarEventSource

    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }

    /// その日にかかっている予定か（終日・日をまたぐ予定も含める）
    func touches(day: Date) -> Bool {
        let dayStart = JapanDate.startOfDay(day)
        let dayEnd = JapanDate.addingDays(1, to: dayStart)
        return start < dayEnd && end > dayStart
    }
}

/// Google カレンダーとのつながり
enum GoogleConnection: Equatable, Sendable {
    /// このビルドに Google の設定が入っていない
    case unavailable
    case disconnected
    case connected(account: String)
    /// つなぎ直しが要る（許可を取り消された・ログインが切れた）
    case expired
}

/// カレンダーを読んでよいか
enum CalendarAccess: Sendable, Equatable {
    /// まだ聞いていない
    case notDetermined
    case granted
    /// 断られた・制限されている・書き込みだけ許可されている
    case denied
}

#if DEBUG
extension CalendarEvent {
    static func sample(_ title: String, day: Date, hour: Int, minute: Int, minutes: Int, location: String) -> CalendarEvent {
        let start = JapanDate.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
        return CalendarEvent(
            id: "\(title)|\(start.timeIntervalSince1970)",
            eventIdentifier: title,
            title: title,
            start: start,
            end: start.addingTimeInterval(TimeInterval(minutes * 60)),
            isAllDay: false,
            location: location,
            calendarTitle: "仕事",
            red: 0.25, green: 0.47, blue: 0.85,
            source: .device
        )
    }

    static func sampleAllDay(_ title: String, day: Date) -> CalendarEvent {
        let start = JapanDate.startOfDay(day)
        return CalendarEvent(
            id: "\(title)|\(start.timeIntervalSince1970)",
            eventIdentifier: title,
            title: title,
            start: start,
            end: JapanDate.addingDays(1, to: start),
            isAllDay: true,
            location: "",
            calendarTitle: "家",
            red: 0.3, green: 0.68, blue: 0.4,
            source: .device
        )
    }

    /// Preview 用の今日と明日の予定
    static func previewWeek(now: Date) -> [CalendarEvent] {
        let today = JapanDate.startOfDay(now)
        let tomorrow = JapanDate.addingDays(1, to: today)
        return [
            .sample("朝会", day: today, hour: 9, minute: 30, minutes: 30, location: ""),
            .sample("歯医者", day: today, hour: 13, minute: 0, minutes: 60, location: "駅前デンタル"),
            .sample("新製品の発表", day: today, hour: 17, minute: 0, minutes: 60, location: "本社 会議室A"),
            .sample("ジム", day: tomorrow, hour: 19, minute: 0, minutes: 90, location: ""),
            .sampleAllDay("引っ越し", day: JapanDate.addingDays(5, to: today)),
        ]
    }
}
#endif

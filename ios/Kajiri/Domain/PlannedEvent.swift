import Foundation

/// カジリがメモから読み取って、カレンダーに入れる予定
struct PlannedEvent: Equatable, Sendable {
    /// 終わりが書いていない予定の長さ
    static let defaultLength: TimeInterval = 60 * 60

    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String

    /// 確認なしで入るので、読めない日時と、今日より前の日は捨てる
    static func make(from dto: EventDTO, now: Date) -> PlannedEvent? {
        let title = dto.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let day = JapanDate.date(day: dto.date), day >= JapanDate.startOfDay(now) else { return nil }
        let location = dto.location ?? ""
        guard let startTime = dto.startTime else {
            return PlannedEvent(title: title, start: day, end: day, isAllDay: true, location: location)
        }
        guard let start = moment(startTime, on: day) else { return nil }
        // 終わりが読めない・始まりより前なら、1時間の予定にする
        let written = dto.endTime.flatMap { moment($0, on: day) }
        let end = written.flatMap { $0 > start ? $0 : nil } ?? start.addingTimeInterval(defaultLength)
        return PlannedEvent(title: title, start: start, end: end, isAllDay: false, location: location)
    }

    /// "15:30" → その日の 15:30
    private static func moment(_ time: String, on day: Date) -> Date? {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0..<24).contains(parts[0]), (0..<60).contains(parts[1]) else { return nil }
        return day.addingTimeInterval(TimeInterval(parts[0] * 3600 + parts[1] * 60))
    }

    /// 同じ予定がもう入っているか。名前が同じで、時刻のある予定は始まりが同じ、終日の予定は同じ日
    func matches(_ event: CalendarEvent) -> Bool {
        guard event.title == title else { return false }
        return isAllDay ? JapanDate.isSameDay(event.start, start) : event.start == start
    }
}

/// カレンダーに入れた結果の1件
struct PlacedEvent: Identifiable, Equatable, Sendable {
    enum State: Equatable, Sendable {
        case added(identifier: String)
        /// 同じ予定がもうあった
        case alreadyThere
        case undone
        /// 許可が無い・入れられなかった
        case notAdded
    }

    let id: UUID
    let event: PlannedEvent
    var state: State
}

/// 1回のメモから入れた予定
struct EventPlacement: Equatable, Sendable {
    static let empty = EventPlacement(events: [], needsAccess: false)

    var events: [PlacedEvent]
    /// iPhone のカレンダーの許可が無くて入れられなかった
    let needsAccess: Bool

    var isEmpty: Bool { events.isEmpty }
}

#if DEBUG
extension EventPlacement {
    private static let sampleEvent = PlannedEvent(
        title: "歯医者",
        start: Date(timeIntervalSince1970: 1_794_549_600),
        end: Date(timeIntervalSince1970: 1_794_553_200),
        isAllDay: false,
        location: ""
    )
    static let sampleAdded = EventPlacement(
        events: [PlacedEvent(id: UUID(), event: sampleEvent, state: .added(identifier: "sample"))],
        needsAccess: false
    )
    static let sampleNeedsAccess = EventPlacement(
        events: [PlacedEvent(id: UUID(), event: sampleEvent, state: .notAdded)],
        needsAccess: true
    )
}
#endif

import Foundation

/// 1日の線に並べるもの。起床から就寝までに、予定と、予定のすき間（空き時間）を時刻順に並べる。
/// 今日の薪は、入る大きさの空き時間に前から置いていく。
@MainActor
enum DayPlanner {
    static let wakeHour = 6
    static let sleepHour = 23
    /// これより短いすき間は空き時間として出さない
    static let minimumFreeMinutes = 10

    struct FreeSlot: Hashable {
        let start: Date
        let end: Date
        /// 今日の空き時間がもう無いときに、今日の薪とカジリの仕事を置いておく箱
        let isOverflow: Bool

        var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
    }

    enum Item: Identifiable {
        case wake(Date)
        case sleep(Date)
        case event(CalendarEvent, isPast: Bool)
        /// isNow: いまの時刻を含む空き時間（カジリの仕事もここに置く）
        case free(FreeSlot, isNow: Bool, steps: [Step])

        var id: String {
            switch self {
            case let .wake(date): "wake|\(date.timeIntervalSince1970)"
            case let .sleep(date): "sleep|\(date.timeIntervalSince1970)"
            case let .event(event, _): "event|\(event.id)"
            case let .free(slot, _, _): "free|\(slot.start.timeIntervalSince1970)"
            }
        }

        var sortDate: Date {
            switch self {
            case let .wake(date), let .sleep(date): date
            case let .event(event, _): event.start
            case let .free(slot, _, _): slot.start
            }
        }
    }

    /// - Parameters:
    ///   - day: 並べる日
    ///   - events: その日の時刻のある予定（終日の予定は入れない）
    ///   - steps: 置く薪（今日でなければ空）
    static func plan(day: Date, now: Date, events: [CalendarEvent], steps: [Step]) -> [Item] {
        let calendar = JapanDate.calendar
        let dayStart = JapanDate.startOfDay(day)
        let wake = calendar.date(bySettingHour: wakeHour, minute: 0, second: 0, of: dayStart) ?? dayStart
        let sleep = calendar.date(bySettingHour: sleepHour, minute: 0, second: 0, of: dayStart) ?? dayStart
        let isToday = JapanDate.isSameDay(day, now)
        let timed = events.filter { !$0.isAllDay && $0.touches(day: day) }.sorted { $0.start < $1.start }

        let from: Date? = if isToday { max(now, wake) } else if dayStart > now { wake } else { nil }
        var slots = from.map { freeSlots(from: $0, to: sleep, busy: timed) } ?? []
        if isToday && slots.isEmpty {
            slots = [FreeSlot(start: now, end: now, isOverflow: true)]
        }
        let placed = place(steps: steps, into: slots)

        var items: [Item] = [.wake(wake), .sleep(sleep)]
        items += timed.map { .event($0, isPast: $0.end <= now) }
        for (index, slot) in slots.enumerated() {
            let isNow = isToday && slot.start <= now.addingTimeInterval(60)
            items.append(.free(slot, isNow: isNow, steps: placed[index]))
        }
        return items.sorted { lhs, rhs in
            if lhs.sortDate != rhs.sortDate { return lhs.sortDate < rhs.sortDate }
            return order(lhs) < order(rhs)
        }
    }

    /// 予定と重ならない、from から to までのすき間
    static func freeSlots(from: Date, to: Date, busy: [CalendarEvent]) -> [FreeSlot] {
        guard from < to else { return [] }
        var slots: [FreeSlot] = []
        var cursor = from
        for event in busy where event.end > cursor {
            if event.start >= to { break }
            if event.start > cursor {
                appendSlot(&slots, start: cursor, end: min(event.start, to))
            }
            cursor = max(cursor, event.end)
        }
        if cursor < to {
            appendSlot(&slots, start: cursor, end: to)
        }
        return slots
    }

    /// 薪を、入る大きさの空き時間に前から置く。どこにも入らない薪は、最初の空き時間に置く
    static func place(steps: [Step], into slots: [FreeSlot]) -> [[Step]] {
        var placed = Array(repeating: [Step](), count: slots.count)
        guard !slots.isEmpty else { return placed }
        var remaining = slots.map(\.minutes)
        for step in steps {
            if let index = remaining.firstIndex(where: { $0 >= step.minutes }) {
                placed[index].append(step)
                remaining[index] -= step.minutes
            } else {
                placed[0].append(step)
            }
        }
        return placed
    }

    private static func appendSlot(_ slots: inout [FreeSlot], start: Date, end: Date) {
        guard Int(end.timeIntervalSince(start) / 60) >= minimumFreeMinutes else { return }
        slots.append(FreeSlot(start: start, end: end, isOverflow: false))
    }

    /// 同じ時刻なら、起床 → 予定 → 空き時間 → 就寝 の順
    private static func order(_ item: Item) -> Int {
        switch item {
        case .wake: 0
        case .event: 1
        case .free: 2
        case .sleep: 3
        }
    }
}

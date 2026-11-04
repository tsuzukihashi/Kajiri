import Foundation
import Observation

/// iPhone のカレンダーの予定を読み、カジリに準備を見てもらう。
/// 予定は Kajiri に写さない（読むたびに iPhone のカレンダーから取る）。
@MainActor
@Observable
final class CalendarUseCase {
    /// 準備を見てもらう期間
    static let prepDays = 14
    /// 一度に送る予定の数の上限（中継サーバの上限 60 より少なく）
    static let prepLimit = 40

    private let repository: any CalendarRepositoryProtocol
    private let api: any KajiriAPIProtocol

    private(set) var access: CalendarAccess
    /// カレンダーが変わるたびに増える。画面はこれを見て読み直す
    private(set) var revision = 0
    @ObservationIgnored private var cache: [String: [CalendarEvent]] = [:]

    init(repository: any CalendarRepositoryProtocol, api: any KajiriAPIProtocol) {
        self.repository = repository
        self.api = api
        self.access = repository.access()
        repository.observeChanges { [weak self] in
            self?.reload()
        }
    }

    // MARK: 許可

    func requestAccess() async {
        access = await repository.requestAccess()
        reload()
    }

    /// 設定から戻ってきたときなど
    func refreshAccess() {
        let latest = repository.access()
        guard latest != access else { return }
        access = latest
        reload()
    }

    // MARK: 読む

    /// その日にかかっている予定（終日も含む）。開始の早い順
    func events(on day: Date) -> [CalendarEvent] {
        _ = revision
        let start = JapanDate.startOfDay(day)
        return events(from: start, to: JapanDate.addingDays(1, to: start))
    }

    func events(from: Date, to: Date) -> [CalendarEvent] {
        _ = revision
        let key = "\(from.timeIntervalSince1970)-\(to.timeIntervalSince1970)"
        if let hit = cache[key] { return hit }
        let found = repository.events(from: from, to: to).sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            return lhs.start < rhs.start
        }
        cache[key] = found
        return found
    }

    /// 予定がある日（"2026-11-04" の形）
    func busyDays(from: Date, to: Date) -> Set<String> {
        var days: Set<String> = []
        for event in events(from: from, to: to) {
            var day = JapanDate.startOfDay(max(event.start, from))
            let last = min(event.end.addingTimeInterval(-1), to)
            while day <= last {
                days.insert(JapanDate.dayString(day))
                day = JapanDate.addingDays(1, to: day)
            }
        }
        return days
    }

    // MARK: 作る・直す

    func editorRequest(for event: CalendarEvent) -> EventEditorRequest? {
        repository.editorRequest(for: event)
    }

    func newEventRequest(on day: Date, now: Date) -> EventEditorRequest? {
        let start: Date
        if JapanDate.isSameDay(day, now) {
            // 次のちょうどの時刻から
            let next = JapanDate.calendar.nextDate(after: now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? now
            start = next
        } else {
            start = JapanDate.calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
        }
        return repository.newEventRequest(draft: EventDraft(title: "", start: start, isAllDay: false, notes: ""))
    }

    /// 丸太の締め切りを、終日の予定として入れる画面
    func deadlineRequest(for log: Log) -> EventEditorRequest? {
        guard let deadline = log.deadline else { return nil }
        let title = String(localized: "締め切り: \(log.title)")
        return repository.newEventRequest(draft: EventDraft(title: title, start: deadline, isAllDay: true, notes: log.deadlineNote))
    }

    // MARK: カジリに準備を見てもらう

    /// この先の予定（すでに丸太にした予定は除く）
    func upcomingForPrep(now: Date, excluding linked: Set<String>) -> [CalendarEvent] {
        let from = JapanDate.startOfDay(now)
        let to = JapanDate.addingDays(Self.prepDays, to: from)
        return events(from: from, to: to)
            .filter { $0.end > now && !linked.contains($0.id) }
            .prefix(Self.prepLimit)
            .map { $0 }
    }

    /// 予定の名前・日時・場所だけを送り、準備が要りそうなものを選んでもらう
    func scanPrep(events: [CalendarEvent], now: Date) async throws -> PrepResult {
        let dtos = events.map { PrepEventDTO(id: $0.id, title: $0.title, when: Self.when($0), location: $0.location) }
        return try await api.prep(events: dtos, today: now)
    }

    /// 予定から丸太を投げるときのメモの下書き
    func throwMemo(for event: CalendarEvent) -> String {
        var memo = "\(Self.when(event)) \(event.title)"
        if !event.location.isEmpty { memo += "（\(event.location)）" }
        return memo + String(localized: "。この準備")
    }

    /// 例: 11/20(木) 10:00〜11:00、12/20(日) 終日
    static func when(_ event: CalendarEvent) -> String {
        let calendar = JapanDate.calendar
        let day = "\(calendar.component(.month, from: event.start))/\(calendar.component(.day, from: event.start))(\(JapanDate.weekdaySymbol(event.start)))"
        if event.isAllDay { return "\(day) " + String(localized: "終日") }
        return "\(day) \(clock(event.start))〜\(clock(event.end))"
    }

    static func clock(_ date: Date) -> String {
        let c = JapanDate.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private func reload() {
        cache = [:]
        revision += 1
    }
}

#if DEBUG
extension CalendarUseCase {
    static func preview(access: CalendarAccess) -> CalendarUseCase {
        CalendarUseCase(
            repository: MockCalendarRepository(access: access, events: access == .granted ? CalendarEvent.previewWeek(now: .now) : []),
            api: MockKajiriAPI(delay: .milliseconds(600), fails: false)
        )
    }
}
#endif

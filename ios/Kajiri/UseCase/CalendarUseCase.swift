import Foundation
import Observation

/// iPhone のカレンダーと、つないだ Google カレンダーの予定を読み、カジリに準備を見てもらう。
/// 予定は Kajiri に写さない（iPhone のカレンダーは読むたびに取り、Google の予定はメモリの中にだけ持つ）。
@MainActor
@Observable
final class CalendarUseCase {
    /// 準備を見てもらう期間
    static let prepDays = 14
    /// 一度に送る予定の数の上限（中継サーバの上限 60 より少なく）
    static let prepLimit = 40
    /// 画面に戻ったときに Google を読み直す間隔（秒）
    static let googleRefreshInterval: TimeInterval = 300

    private let repository: any CalendarRepositoryProtocol
    private let google: any GoogleCalendarRepositoryProtocol
    private let api: any KajiriAPIProtocol

    private(set) var access: CalendarAccess
    /// カレンダーが変わるたびに増える。画面はこれを見て読み直す
    private(set) var revision = 0
    private(set) var googleConnection: GoogleConnection
    /// つなぐ・読む途中
    private(set) var isGoogleWorking = false
    /// 読めなかったときに、カードに出す文
    private(set) var googleMessage: String?
    @ObservationIgnored private var cache: [String: [CalendarEvent]] = [:]
    @ObservationIgnored private var googleEvents: [CalendarEvent] = []
    /// 読んである期間
    @ObservationIgnored private var googleRange: (from: Date, to: Date)?
    @ObservationIgnored private var googleLoadedAt: Date?
    @ObservationIgnored private var didRestoreGoogle = false

    init(repository: any CalendarRepositoryProtocol, google: any GoogleCalendarRepositoryProtocol, api: any KajiriAPIProtocol) {
        self.repository = repository
        self.google = google
        self.api = api
        self.access = repository.access()
        self.googleConnection = google.isAvailable ? .disconnected : .unavailable
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

    // MARK: カジリが予定を入れる

    /// メモから読み取った予定を、確認なしで iPhone のカレンダーに入れる。
    /// 許可をまだ聞いていなければ、ここで初めて聞く
    func place(_ events: [EventDTO], now: Date) async -> EventPlacement {
        let planned = events.compactMap { PlannedEvent.make(from: $0, now: now) }
        guard !planned.isEmpty else { return .empty }
        if access == .notDetermined { await requestAccess() }
        guard access == .granted else {
            return EventPlacement(events: planned.map { PlacedEvent(id: UUID(), event: $0, state: .notAdded) }, needsAccess: true)
        }
        let placed = planned.map { event in
            PlacedEvent(id: UUID(), event: event, state: put(event))
        }
        reload()
        return EventPlacement(events: placed, needsAccess: false)
    }

    private func put(_ event: PlannedEvent) -> PlacedEvent.State {
        let day = JapanDate.startOfDay(event.start)
        let existing = events(from: day, to: JapanDate.addingDays(1, to: day))
        if existing.contains(where: event.matches) { return .alreadyThere }
        guard let identifier = try? repository.add(event) else { return .notAdded }
        return .added(identifier: identifier)
    }

    /// 入れた予定を1件消す。消せなければそのまま返す
    func undo(_ placed: PlacedEvent, in placement: EventPlacement) -> EventPlacement {
        guard case let .added(identifier) = placed.state, (try? repository.remove(identifier: identifier)) != nil else {
            return placement
        }
        reload()
        var updated = placement
        updated.events = placement.events.map { event in
            guard event.id == placed.id else { return event }
            return PlacedEvent(id: event.id, event: event.event, state: .undone)
        }
        return updated
    }

    /// 入れた予定を全部消す。消せなかった数を返す（黙って残さない）
    @discardableResult
    func undoAll(in placement: EventPlacement) -> Int {
        var failed = 0
        for placed in placement.events {
            if case let .added(identifier) = placed.state {
                if (try? repository.remove(identifier: identifier)) == nil { failed += 1 }
            }
        }
        reload()
        return failed
    }


    // MARK: Google カレンダー

    var isGoogleConnected: Bool {
        if case .connected = googleConnection { return true }
        return false
    }

    /// iPhone のカレンダーか Google のどちらかから、予定が読めるか
    var canReadEvents: Bool { access == .granted || isGoogleConnected }

    func connectGoogle(now: Date) async {
        guard !isGoogleWorking else { return }
        isGoogleWorking = true
        defer { isGoogleWorking = false }
        googleMessage = nil
        do {
            // やめたときは nil で、何も変えない
            guard let account = try await google.connect() else { return }
            didRestoreGoogle = true
            googleConnection = .connected(account: account)
            await loadGoogle(from: Self.defaultRange(now: now).from, to: Self.defaultRange(now: now).to)
        } catch {
            await handleGoogle(error)
        }
    }

    func disconnectGoogle() async {
        guard !isGoogleWorking else { return }
        isGoogleWorking = true
        defer { isGoogleWorking = false }
        await google.disconnect()
        googleConnection = .disconnected
        googleMessage = nil
        clearGoogle()
    }

    /// 画面に戻ったとき。起動して最初の1回は前のログインに戻り、そのあとは間をあけて読み直す
    func refreshGoogle(now: Date) async {
        guard googleConnection != .unavailable else { return }
        guard didRestoreGoogle else {
            didRestoreGoogle = true
            await restoreGoogle(now: now)
            return
        }
        guard isGoogleConnected else { return }
        if let last = googleLoadedAt, now.timeIntervalSince(last) < Self.googleRefreshInterval { return }
        let range = googleRange ?? Self.defaultRange(now: now)
        await fetchGoogle(from: range.from, to: range.to)
    }

    /// まだ読んでいない期間を開いたとき（別の月に移ったなど）
    func loadGoogle(from: Date, to: Date) async {
        guard isGoogleConnected else { return }
        if let range = googleRange {
            if range.from <= from && to <= range.to { return }
            await fetchGoogle(from: min(range.from, from), to: max(range.to, to))
        } else {
            await fetchGoogle(from: from, to: to)
        }
    }

    /// 読めなかったあとの「もう一度」。読んでいる間は isGoogleWorking でくるくるを出す
    func retryGoogle(now: Date) async {
        guard isGoogleConnected, !isGoogleWorking else { return }
        isGoogleWorking = true
        defer { isGoogleWorking = false }
        let range = googleRange ?? Self.defaultRange(now: now)
        await fetchGoogle(from: range.from, to: range.to)
    }

    private func restoreGoogle(now: Date) async {
        do {
            guard let account = try await google.restore() else { return }
            googleConnection = .connected(account: account)
            let range = Self.defaultRange(now: now)
            await fetchGoogle(from: range.from, to: range.to)
        } catch {
            await handleGoogle(error)
        }
    }

    private func fetchGoogle(from: Date, to: Date) async {
        isGoogleWorking = true
        defer { isGoogleWorking = false }
        do {
            let found = try await google.events(from: from, to: to)
            // 読んでいる間に切られたら捨てる
            guard isGoogleConnected else { return }
            googleEvents = found
            googleRange = (from, to)
            googleLoadedAt = .now
            googleMessage = nil
            reload()
        } catch {
            await handleGoogle(error)
        }
    }

    private func handleGoogle(_ error: Error) async {
        switch error as? GoogleCalendarError {
        case .notAuthorized:
            googleConnection = .expired
            googleMessage = String(localized: "Google につながらなかった。つなぎ直すと、また並ぶ。")
            clearGoogle()
        case .scopeMissing:
            // 足りない許可のままログインを残さない
            await google.disconnect()
            googleConnection = .disconnected
            googleMessage = String(localized: "カレンダーのチェックが外れていた。もう一度つなぐときにチェックを入れると、予定が読める。")
            clearGoogle()
        case .requestFailed, .none:
            googleMessage = String(localized: "Google カレンダーを読めなかった。通信を確かめて、もう一度。")
        }
    }

    private func clearGoogle() {
        googleEvents = []
        googleRange = nil
        googleLoadedAt = nil
        reload()
    }

    /// 最初に読む期間（前後の月の表示と、準備を見る2週間が入るように）
    private static func defaultRange(now: Date) -> (from: Date, to: Date) {
        (JapanDate.addingDays(-35, to: now), JapanDate.addingDays(70, to: now))
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
        let fromGoogle = googleEvents.filter { $0.start < to && $0.end > from }
        let found = CalendarMerger.merged(device: repository.events(from: from, to: to), google: fromGoogle).sorted { lhs, rhs in
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
        whenText(start: event.start, end: event.end, isAllDay: event.isAllDay)
    }

    static func whenText(start: Date, end: Date, isAllDay: Bool) -> String {
        let calendar = JapanDate.calendar
        let day = "\(calendar.component(.month, from: start))/\(calendar.component(.day, from: start))(\(JapanDate.weekdaySymbol(start)))"
        if isAllDay { return "\(day) " + String(localized: "終日") }
        return "\(day) \(clock(start))〜\(clock(end))"
    }

    static func clock(_ date: Date) -> String {
        let c = JapanDate.calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    /// 読み直す（カレンダーが変わったとき）
    func reload() {
        cache = [:]
        revision += 1
    }
}

#if DEBUG
extension CalendarUseCase {
    static func preview(access: CalendarAccess) -> CalendarUseCase {
        CalendarUseCase(
            repository: MockCalendarRepository(access: access, events: access == .granted ? CalendarEvent.previewWeek(now: .now) : []),
            google: MockGoogleCalendarRepository(isAvailable: true, account: nil, connectsAs: "kajiri@example.com", events: [], failure: nil),
            api: MockKajiriAPI(delay: .milliseconds(600), fails: false)
        )
    }

    /// Preview 用。Google をつないだ状態にして返す
    static func previewGoogle(failure: GoogleCalendarError?) async -> CalendarUseCase {
        let useCase = CalendarUseCase(
            repository: MockCalendarRepository(access: .denied, events: []),
            google: MockGoogleCalendarRepository(isAvailable: true, account: "kajiri@example.com", connectsAs: nil, events: CalendarEvent.previewWeek(now: .now), failure: failure),
            api: MockKajiriAPI(delay: .milliseconds(600), fails: false)
        )
        await useCase.refreshGoogle(now: .now)
        return useCase
    }
}
#endif

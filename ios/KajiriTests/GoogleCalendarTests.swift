import Foundation
import Testing
@testable import Kajiri

@MainActor
struct GoogleCalendarTests {
    private let calendar = GoogleCalendarEntry(
        id: "work@example.com", summary: "仕事", summaryOverride: nil, backgroundColor: "#FF8000", selected: true, hidden: nil
    )

    private func decode(_ json: String) throws -> GoogleEventList {
        try JSONDecoder().decode(GoogleEventList.self, from: Data(json.utf8))
    }

    private func device(_ title: String, start: Date, end: Date, isAllDay: Bool) -> CalendarEvent {
        CalendarEvent(
            id: "d-\(title)", eventIdentifier: title, title: title, start: start, end: end,
            isAllDay: isAllDay, location: "", calendarTitle: "", red: 0, green: 0, blue: 0, source: .device
        )
    }

    private func google(_ title: String, start: Date, end: Date, isAllDay: Bool) -> CalendarEvent {
        CalendarEvent(
            id: "g-\(title)", eventIdentifier: title, title: title, start: start, end: end,
            isAllDay: isAllDay, location: "", calendarTitle: "", red: 0, green: 0, blue: 0, source: .google(link: nil)
        )
    }

    @Test("時刻のある予定は、時差つきの日時から読む。名前・場所・リンク・色も入る")
    func timedEvent() throws {
        let list = try decode("""
        {"items":[{"id":"e1","status":"confirmed","summary":"発表","location":"本社",
          "start":{"dateTime":"2026-11-20T10:00:00+09:00"},"end":{"dateTime":"2026-11-20T02:00:00Z"},
          "htmlLink":"https://www.google.com/calendar/event?eid=abc"}]}
        """)
        let event = try #require(GoogleEventMapper.events(from: list, calendar: calendar).first)
        #expect(event.id == "google|work@example.com|e1")
        #expect(event.title == "発表")
        #expect(event.location == "本社")
        #expect(!event.isAllDay)
        #expect(event.minutes == 60)
        #expect(event.calendarTitle == "仕事")
        #expect(abs(event.red - 1) < 0.001)
        #expect(event.blue == 0)
        #expect(event.source == .google(link: URL(string: "https://www.google.com/calendar/event?eid=abc")))
    }

    @Test("終日の予定は日付で読み、終わりの日は含まない")
    func allDayEvent() throws {
        let list = try decode("""
        {"items":[{"id":"e2","summary":"引っ越し","start":{"date":"2026-12-20"},"end":{"date":"2026-12-21"}}]}
        """)
        let event = try #require(GoogleEventMapper.events(from: list, calendar: calendar).first)
        let day = try #require(JapanDate.date(day: "2026-12-20"))
        #expect(event.isAllDay)
        #expect(event.touches(day: day))
        #expect(!event.touches(day: JapanDate.addingDays(1, to: day)))
    }

    @Test("消された予定と、日時の無い予定は並べない。名前の無い予定には代わりの名前を付ける")
    func skips() throws {
        let list = try decode("""
        {"items":[
          {"id":"gone","status":"cancelled","start":{"date":"2026-12-20"},"end":{"date":"2026-12-21"}},
          {"id":"nodate","status":"confirmed"},
          {"id":"private","start":{"date":"2026-12-20"},"end":{"date":"2026-12-21"}}
        ]}
        """)
        let events = GoogleEventMapper.events(from: list, calendar: calendar)
        #expect(events.map(\.id) == ["google|work@example.com|private"])
        #expect(events.first?.title == "（名前のない予定）")
    }

    @Test("くり返しの予定は、回ごとに別の id で、もとの予定の名前を持つ")
    func recurring() throws {
        let list = try decode("""
        {"items":[{"id":"base_20261120","recurringEventId":"base",
          "start":{"dateTime":"2026-11-20T10:00:00+09:00"},"end":{"dateTime":"2026-11-20T11:00:00+09:00"}}]}
        """)
        let event = try #require(GoogleEventMapper.events(from: list, calendar: calendar).first)
        #expect(event.id == "google|work@example.com|base_20261120")
        #expect(event.eventIdentifier == "base")
    }

    @Test("Google カレンダーで表示をオンにしているカレンダーだけを読む")
    func shownCalendars() {
        let on = GoogleCalendarEntry(id: "a", summary: "a", summaryOverride: "自分の名前", backgroundColor: nil, selected: true, hidden: false)
        let off = GoogleCalendarEntry(id: "b", summary: "b", summaryOverride: nil, backgroundColor: nil, selected: nil, hidden: nil)
        let hidden = GoogleCalendarEntry(id: "c", summary: "c", summaryOverride: nil, backgroundColor: nil, selected: true, hidden: true)
        #expect(on.isShown)
        #expect(on.title == "自分の名前")
        #expect(!off.isShown)
        #expect(!hidden.isShown)
    }

    @Test("色が読めないときは灰色")
    func color() {
        #expect(GoogleEventMapper.rgb(hex: nil) == (0.5, 0.5, 0.5))
        #expect(GoogleEventMapper.rgb(hex: "red") == (0.5, 0.5, 0.5))
        #expect(GoogleEventMapper.rgb(hex: "#000000") == (0, 0, 0))
    }

    @Test("iPhone のカレンダーと同じ予定は、直せる iPhone 側を残す")
    func mergesDuplicates() throws {
        let day = try #require(JapanDate.date(day: "2026-11-20"))
        let start = day.addingTimeInterval(3600)
        let end = start.addingTimeInterval(3600)
        let merged = CalendarMerger.merged(
            device: [
                device("発表", start: start, end: end, isAllDay: false),
                // iPhone の終日は 23:59:59 に終わる。Google は次の日の 0 時
                device("引っ越し", start: day, end: day.addingTimeInterval(86399), isAllDay: true),
            ],
            google: [
                google("発表", start: start, end: end, isAllDay: false),
                google("引っ越し", start: day, end: JapanDate.addingDays(1, to: day), isAllDay: true),
                google("歯医者", start: start, end: end, isAllDay: false),
            ]
        )
        #expect(merged.map(\.id) == ["d-発表", "d-引っ越し", "g-歯医者"])
    }

    @Test("Google をつなぐと、iPhone のカレンダーを断っていても予定が読める")
    func connectsWithoutDeviceAccess() async throws {
        let now = try #require(JapanDate.date(day: "2026-11-20"))
        let event = google("発表", start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200), isAllDay: false)
        let useCase = CalendarUseCase(
            repository: MockCalendarRepository(access: .denied, events: []),
            google: MockGoogleCalendarRepository(isAvailable: true, account: nil, connectsAs: "a@example.com", events: [event], failure: nil),
            api: MockKajiriAPI(delay: .zero, fails: false)
        )
        #expect(!useCase.canReadEvents)
        await useCase.connectGoogle(now: now)
        #expect(useCase.googleConnection == .connected(account: "a@example.com"))
        #expect(useCase.canReadEvents)
        #expect(useCase.events(on: now).map(\.id) == ["g-発表"])

        await useCase.disconnectGoogle()
        #expect(useCase.googleConnection == .disconnected)
        #expect(!useCase.canReadEvents)
        #expect(useCase.events(on: now).isEmpty)
    }

    @Test("ログインの画面でやめたら、何も変えない")
    func cancelled() async throws {
        let useCase = CalendarUseCase(
            repository: MockCalendarRepository(access: .denied, events: []),
            google: MockGoogleCalendarRepository(isAvailable: true, account: nil, connectsAs: nil, events: [], failure: nil),
            api: MockKajiriAPI(delay: .zero, fails: false)
        )
        await useCase.connectGoogle(now: .now)
        #expect(useCase.googleConnection == .disconnected)
        #expect(useCase.googleMessage == nil)
    }

    @Test("ログインが切れたら、予定を消して、つなぎ直しを出す")
    func expired() async {
        let useCase = CalendarUseCase(
            repository: MockCalendarRepository(access: .denied, events: []),
            google: MockGoogleCalendarRepository(isAvailable: true, account: "a@example.com", connectsAs: nil, events: [], failure: .notAuthorized),
            api: MockKajiriAPI(delay: .zero, fails: false)
        )
        await useCase.refreshGoogle(now: .now)
        #expect(useCase.googleConnection == .expired)
        #expect(useCase.googleMessage != nil)
        #expect(!useCase.canReadEvents)
    }

    @Test("読めなかっただけなら、つないだまま文を出す")
    func failedToRead() async {
        let useCase = CalendarUseCase(
            repository: MockCalendarRepository(access: .denied, events: []),
            google: MockGoogleCalendarRepository(isAvailable: true, account: "a@example.com", connectsAs: nil, events: [], failure: .requestFailed),
            api: MockKajiriAPI(delay: .zero, fails: false)
        )
        await useCase.refreshGoogle(now: .now)
        #expect(useCase.googleConnection == .connected(account: "a@example.com"))
        #expect(useCase.googleMessage != nil)
    }

    @Test("Google の設定が無いビルドでは、つなぐものを出さない")
    func unavailable() async {
        let useCase = CalendarUseCase(
            repository: MockCalendarRepository(access: .granted, events: []),
            google: MockGoogleCalendarRepository(isAvailable: false, account: nil, connectsAs: nil, events: [], failure: nil),
            api: MockKajiriAPI(delay: .zero, fails: false)
        )
        await useCase.refreshGoogle(now: .now)
        #expect(useCase.googleConnection == .unavailable)
    }
}

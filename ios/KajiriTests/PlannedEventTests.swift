import Foundation
import Testing
@testable import Kajiri

@MainActor
struct PlannedEventTests {
    private func now() throws -> Date {
        try #require(JapanDate.date(day: "2026-11-07")).addingTimeInterval(10 * 3600)
    }

    private func dto(_ title: String, _ date: String, _ start: String?, _ end: String?) -> EventDTO {
        EventDTO(title: title, date: date, startTime: start, endTime: end, location: nil)
    }

    private func useCase(access: CalendarAccess, events: [CalendarEvent]) -> (CalendarUseCase, MockCalendarRepository) {
        let repository = MockCalendarRepository(access: access, events: events)
        let useCase = CalendarUseCase(
            repository: repository,
            google: MockGoogleCalendarRepository(isAvailable: false, account: nil, connectsAs: nil, events: [], failure: nil),
            api: MockKajiriAPI(delay: .zero, fails: false)
        )
        return (useCase, repository)
    }

    @Test("終わりが書いていない予定は1時間にする")
    func defaultLength() throws {
        let event = try #require(PlannedEvent.make(from: dto("歯医者", "2026-11-13", "15:00", nil), now: now()))
        #expect(!event.isAllDay)
        #expect(event.end.timeIntervalSince(event.start) == 3600)
        #expect(CalendarUseCase.whenText(start: event.start, end: event.end, isAllDay: false) == "11/13(金) 15:00〜16:00")
    }

    @Test("終わりが始まりより前なら、1時間にする")
    func wrongEnd() throws {
        let event = try #require(PlannedEvent.make(from: dto("飲み会", "2026-11-13", "19:00", "18:00"), now: now()))
        #expect(event.end.timeIntervalSince(event.start) == 3600)
    }

    @Test("時刻が無ければ終日の予定にする")
    func allDay() throws {
        let event = try #require(PlannedEvent.make(from: dto("引っ越し", "2026-12-20", nil, nil), now: now()))
        #expect(event.isAllDay)
    }

    @Test("読めない日時と、今日より前の日は入れない")
    func rejects() throws {
        #expect(PlannedEvent.make(from: dto("昨日", "2026-11-06", "15:00", nil), now: try now()) == nil)
        #expect(PlannedEvent.make(from: dto("読めない日", "来週", nil, nil), now: try now()) == nil)
        #expect(PlannedEvent.make(from: dto("読めない時刻", "2026-11-13", "25:00", nil), now: try now()) == nil)
        #expect(PlannedEvent.make(from: dto("  ", "2026-11-13", "15:00", nil), now: try now()) == nil)
        #expect(PlannedEvent.make(from: dto("今日", "2026-11-07", "09:00", nil), now: try now()) != nil)
    }

    @Test("許可があれば確認なしで入り、戻すと消える")
    func placesAndUndoes() async throws {
        let (calendar, _) = useCase(access: .granted, events: [])
        let day = try #require(JapanDate.date(day: "2026-11-13"))
        let placement = await calendar.place([dto("歯医者", "2026-11-13", "15:00", nil)], now: try now())
        #expect(calendar.events(on: day).map(\.title) == ["歯医者"])
        let placed = try #require(placement.events.first)
        let undone = calendar.undo(placed, in: placement)
        #expect(undone.events.first?.state == .undone)
        #expect(calendar.events(on: day).isEmpty)
    }

    @Test("同じ予定がもうあれば入れない")
    func skipsDuplicate() async throws {
        let (calendar, _) = useCase(access: .granted, events: [])
        let day = try #require(JapanDate.date(day: "2026-11-13"))
        _ = await calendar.place([dto("歯医者", "2026-11-13", "15:00", nil)], now: try now())
        let second = await calendar.place([dto("歯医者", "2026-11-13", "15:00", nil)], now: try now())
        #expect(second.events.first?.state == .alreadyThere)
        #expect(calendar.events(on: day).count == 1)
    }

    @Test("許可が無ければ入れず、許可を求める")
    func needsAccess() async throws {
        let (calendar, _) = useCase(access: .denied, events: [])
        let placement = await calendar.place([dto("歯医者", "2026-11-13", "15:00", nil)], now: try now())
        #expect(placement.needsAccess)
        #expect(placement.events.first?.state == .notAdded)
    }

    @Test("入れられなかったら、入れたと言わない")
    func writeFails() async throws {
        let (calendar, repository) = useCase(access: .granted, events: [])
        repository.failsToWrite = true
        let placement = await calendar.place([dto("歯医者", "2026-11-13", "15:00", nil)], now: try now())
        #expect(placement.events.first?.state == .notAdded)
    }

    @Test("予定が無いメモでは、何も聞かない")
    func nothingToPlace() async throws {
        let (calendar, _) = useCase(access: .notDetermined, events: [])
        let placement = await calendar.place([], now: try now())
        #expect(placement == .empty)
    }

    @Test("予定を返さない前の中継サーバの答えも読める")
    func decodesOldServer() throws {
        let json = #"{"log_title":"a","deadline":null,"deadline_note":"","why":"","steps":[],"comment":"c"}"#
        let result = try JSONDecoder().decode(DecomposeResult.self, from: Data(json.utf8))
        #expect(result.events == nil)
    }
}

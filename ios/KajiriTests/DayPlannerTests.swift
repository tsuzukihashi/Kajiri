import Foundation
import Testing
@testable import Kajiri

@MainActor
struct DayPlannerTests {
    private let day = JapanDate.date(day: "2026-11-04")!

    private func at(_ hour: Int, _ minute: Int) -> Date {
        JapanDate.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    private func event(_ title: String, _ hour: Int, _ minute: Int, minutes: Int) -> CalendarEvent {
        let start = at(hour, minute)
        return CalendarEvent(
            id: title, eventIdentifier: title, title: title, start: start, end: start.addingTimeInterval(Double(minutes * 60)),
            isAllDay: false, location: "", calendarTitle: "", red: 0, green: 0, blue: 0, source: .device
        )
    }

    private func step(_ title: String, minutes: Int) -> Step {
        Step(order: 0, dto: .sample(title, minutes: minutes, owner: .me, quadrant: .today, work: nil))
    }

    private func slots(_ items: [DayPlanner.Item]) -> [(DayPlanner.FreeSlot, [Step])] {
        items.compactMap { if case let .free(slot, _, steps) = $0 { (slot, steps) } else { nil } }
    }

    @Test("今日: いまから就寝までのうち、予定と重ならないところが空き時間になる")
    func freeSlotsSkipEvents() {
        let items = DayPlanner.plan(day: day, now: at(10, 0), events: [event("会議", 13, 0, minutes: 60)], steps: [])
        let free = slots(items).map { ($0.0.start, $0.0.end) }
        #expect(free.count == 2)
        #expect(free[0] == (at(10, 0), at(13, 0)))
        #expect(free[1] == (at(14, 0), at(23, 0)))
    }

    @Test("10分より短いすき間は空き時間にしない")
    func shortGapsAreDropped() {
        let events = [event("A", 10, 0, minutes: 60), event("B", 11, 5, minutes: 60)]
        let free = slots(DayPlanner.plan(day: day, now: at(10, 0), events: events, steps: []))
        #expect(free.count == 1)
        #expect(free[0].0.start == at(12, 5))
    }

    @Test("重なった予定は、まとめて1つの忙しい時間として扱う")
    func overlappingEvents() {
        let events = [event("A", 10, 0, minutes: 120), event("B", 11, 0, minutes: 30)]
        let free = slots(DayPlanner.plan(day: day, now: at(9, 0), events: events, steps: []))
        #expect(free.map(\.0.start) == [at(9, 0), at(12, 0)])
    }

    @Test("薪は、入る大きさの空き時間に前から置く")
    func stepsGoWhereTheyFit() {
        let events = [event("A", 10, 15, minutes: 60)]
        let small = step("5分の薪", minutes: 5)
        let big = step("15分の薪", minutes: 15)
        // 10:00〜10:15 の15分には5分だけ入り、15分は 11:15 以降へ
        let free = slots(DayPlanner.plan(day: day, now: at(10, 0), events: events, steps: [small, big]))
        #expect(free[0].1.map(\.title) == ["5分の薪"])
        #expect(free[1].1.map(\.title) == ["15分の薪"])
    }

    @Test("今日の空き時間がもう無いときは、薪を置いておく箱を1つ出す")
    func overflowWhenNoFreeTime() {
        let items = DayPlanner.plan(day: day, now: at(23, 30), events: [], steps: [step("薪", minutes: 5)])
        let free = slots(items)
        #expect(free.count == 1)
        #expect(free[0].0.isOverflow)
        #expect(free[0].1.count == 1)
    }

    @Test("過ぎた日には空き時間を出さない。先の日は起床から")
    func pastAndFutureDays() {
        let past = DayPlanner.plan(day: day, now: JapanDate.addingDays(1, to: at(10, 0)), events: [], steps: [])
        #expect(slots(past).isEmpty)
        let future = DayPlanner.plan(day: day, now: JapanDate.addingDays(-1, to: at(10, 0)), events: [], steps: [])
        #expect(slots(future).map(\.0.start) == [at(6, 0)])
    }

    @Test("並びは時刻順で、終わった予定には印が付く")
    func orderAndPast() {
        let items = DayPlanner.plan(day: day, now: at(12, 0), events: [event("朝会", 9, 30, minutes: 30)], steps: [])
        #expect(items.first.map { if case .wake = $0 { true } else { false } } == true)
        #expect(items.last.map { if case .sleep = $0 { true } else { false } } == true)
        let past = items.compactMap { if case let .event(_, isPast) = $0 { isPast } else { nil } }
        #expect(past == [true])
    }
}

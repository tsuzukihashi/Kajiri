import Foundation
import Testing
@testable import Kajiri

@MainActor
struct CalendarFormatTests {
    @Test("カジリに送る日時は「11/20(金) 10:00〜11:00」「終日」の形")
    func whenText() {
        let day = JapanDate.date(day: "2026-11-20")!
        let start = JapanDate.calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day)!
        let timed = CalendarEvent(
            id: "a", eventIdentifier: "a", title: "発表", start: start, end: start.addingTimeInterval(3600),
            isAllDay: false, location: "", calendarTitle: "", red: 0, green: 0, blue: 0
        )
        let allDay = CalendarEvent(
            id: "b", eventIdentifier: "b", title: "引っ越し", start: day, end: JapanDate.addingDays(1, to: day),
            isAllDay: true, location: "", calendarTitle: "", red: 0, green: 0, blue: 0
        )
        #expect(CalendarUseCase.when(timed) == "11/20(金) 10:00〜11:00")
        #expect(CalendarUseCase.when(allDay) == "11/20(金) 終日")
    }

    @Test("日をまたぐ予定は、かかっている日すべてに出る")
    func touches() {
        let day = JapanDate.date(day: "2026-11-20")!
        let start = JapanDate.calendar.date(bySettingHour: 23, minute: 0, second: 0, of: day)!
        let event = CalendarEvent(
            id: "c", eventIdentifier: "c", title: "夜行バス", start: start, end: start.addingTimeInterval(7 * 3600),
            isAllDay: false, location: "", calendarTitle: "", red: 0, green: 0, blue: 0
        )
        #expect(event.touches(day: day))
        #expect(event.touches(day: JapanDate.addingDays(1, to: day)))
        #expect(!event.touches(day: JapanDate.addingDays(2, to: day)))
    }
}

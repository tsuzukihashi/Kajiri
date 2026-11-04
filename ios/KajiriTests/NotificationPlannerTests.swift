import Foundation
import SwiftData
import Testing
@testable import Kajiri

@MainActor
struct NotificationPlannerTests {
    /// 2026-11-04（水）
    private let day = JapanDate.date(day: "2026-11-04")!

    private func at(_ hour: Int, on day: Date) -> Date {
        JapanDate.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func context() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Log.self, Step.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    @Test("何も無ければ、通知を1つも入れない")
    func nothingToSay() {
        #expect(NotificationPlanner.plan(steps: [], logs: [], now: at(10, on: day)).isEmpty)
    }

    @Test("自分の番の薪があれば、次の朝8時に1本目を知らせる。締め切りの前の日の夜と、月曜の朝も入る")
    func morningDeadlineAndWeekly() throws {
        let context = try context()
        let log = Log(
            title: "年末調整", memo: "", deadline: JapanDate.date(day: "2026-11-20"), deadlineNote: "", why: "", kajiriComment: "",
            createdAt: day, sourceEventID: nil
        )
        context.insert(log)
        let step = Step(order: 0, dto: .sample("封筒を机に出す", minutes: 3, owner: .me, quadrant: .today, work: nil))
        context.insert(step)
        step.log = log

        let items = NotificationPlanner.plan(steps: [step], logs: [log], now: at(10, on: day))
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        #expect(byID["kajiri.morning"]?.fireAt == at(8, on: JapanDate.addingDays(1, to: day)))
        #expect(byID["kajiri.morning"]?.body.contains("封筒を机に出す") == true)
        #expect(byID["kajiri.deadline.\(log.uuid.uuidString)"]?.fireAt == at(19, on: JapanDate.date(day: "2026-11-19")!))
        #expect(byID["kajiri.weekly"]?.fireAt == JapanDate.date(day: "2026-11-09")!.addingTimeInterval(8.5 * 3600))
    }

    @Test("朝の7時に開いたら、その日の8時に知らせる")
    func sameMorning() throws {
        let context = try context()
        let step = Step(order: 0, dto: .sample("薪", minutes: 3, owner: .me, quadrant: .today, work: nil))
        context.insert(step)
        let morning = NotificationPlanner.plan(steps: [step], logs: [], now: at(7, on: day)).first { $0.id == "kajiri.morning" }
        #expect(morning?.fireAt == at(8, on: day))
    }

    @Test("締め切りを過ぎた丸太の前の日の通知は入れない")
    func pastDeadline() throws {
        let context = try context()
        let log = Log(
            title: "過ぎた", memo: "", deadline: JapanDate.date(day: "2026-11-01"), deadlineNote: "", why: "", kajiriComment: "",
            createdAt: day, sourceEventID: nil
        )
        context.insert(log)
        let items = NotificationPlanner.plan(steps: [], logs: [log], now: at(10, on: day))
        #expect(!items.contains { $0.id.hasPrefix("kajiri.deadline") })
    }
}

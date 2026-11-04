import Foundation
import SwiftData
import Testing
@testable import Kajiri

@MainActor
struct TodayPickerTests {
    private let now = JapanDate.calendar.date(bySettingHour: 10, minute: 0, second: 0, of: JapanDate.date(day: "2026-11-04")!)!

    private func makeLog(_ context: ModelContext, _ titles: [(String, StepOwner)]) -> [Step] {
        let log = Log(title: "丸太", memo: "", deadline: nil, deadlineNote: "", why: "", kajiriComment: "", createdAt: now, sourceEventID: nil)
        context.insert(log)
        return titles.enumerated().map { index, item in
            let step = Step(order: index * 10, dto: .sample(item.0, minutes: 5, owner: item.1, quadrant: .today, work: nil))
            context.insert(step)
            step.log = log
            return step
        }
    }

    private func context() throws -> ModelContext {
        let container = try ModelContainer(for: Log.self, Step.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    @Test("同じ丸太では、順番が前の自分の薪が残っているあいだ次を出さない")
    func oneAtATimePerLog() throws {
        let context = try context()
        let steps = makeLog(context, [("1本目", .me), ("2本目", .me)])
        let picks = TodayPicker.pick(from: steps, now: now, limit: 3)
        #expect(picks.open.map(\.title) == ["1本目"])
    }

    @Test("カジリの番・仲間の番は今日の薪に出さない")
    func onlyMine() throws {
        let context = try context()
        let steps = makeLog(context, [("調べる", .kajiri), ("頼む", .other), ("やる", .me)])
        #expect(TodayPicker.pick(from: steps, now: now, limit: 3).open.map(\.title) == ["やる"])
    }

    @Test("今日片づけた分も数に入れる（3本終えたら、もう出さない）")
    func doneCountsTowardLimit() throws {
        let context = try context()
        var steps: [Step] = []
        for index in 0..<4 { steps += makeLog(context, [("薪\(index)", .me)]) }
        for step in steps.prefix(3) {
            step.isDone = true
            step.doneAt = now
        }
        let picks = TodayPicker.pick(from: steps, now: now, limit: 3)
        #expect(picks.done.count == 3)
        #expect(picks.open.isEmpty)
        #expect(picks.isAllDone)
    }

    @Test("「いまじゃない」にした薪は、明日まで出さない")
    func postponed() throws {
        let context = try context()
        let steps = makeLog(context, [("あとで", .me)])
        steps[0].notBefore = JapanDate.addingDays(1, to: now)
        #expect(TodayPicker.pick(from: steps, now: now, limit: 3).open.isEmpty)
        #expect(TodayPicker.pick(from: steps, now: JapanDate.addingDays(1, to: now), limit: 3).open.count == 1)
    }

    @Test("見積もりの何倍かかるかは、3本そろうまで出さない")
    func overrun() throws {
        let context = try context()
        let steps = makeLog(context, [("a", .me), ("b", .me), ("c", .me)])
        for step in steps.prefix(2) {
            step.isDone = true
            step.doneAt = now
            step.actualMinutes = 10
        }
        #expect(TodayPicker.overrun(of: steps) == nil)
        steps[2].isDone = true
        steps[2].doneAt = now
        steps[2].actualMinutes = 10
        #expect(TodayPicker.overrun(of: steps) == 2)
    }
}

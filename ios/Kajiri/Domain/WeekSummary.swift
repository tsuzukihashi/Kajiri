import Foundation

/// 1週間（日曜はじまり）の記録をまとめたもの。ふりかえりの画面と、カジリに送る中身の両方に使う
@MainActor
struct WeekSummary {
    let start: Date
    /// 日〜土の、片づけた薪の数
    let days: [Int]
    let done: [Step]
    /// カジリが運んだ下書き・調べもの
    let kajiriDone: Int
    /// 「あとで」や割り直しのあとに片づけた薪
    let comeback: Int
    /// 「いまじゃない」にしたまま残っている薪
    let postponed: [Step]
    let overrun: Double?
    let thrown: Int

    var end: Date { JapanDate.addingDays(6, to: start) }
    var key: String { JapanDate.dayString(start) }
    var isEmpty: Bool { done.isEmpty && kajiriDone == 0 && thrown == 0 }

    static func make(steps: [Step], logs: [Log], weekStart: Date) -> WeekSummary {
        let start = JapanDate.startOfDay(weekStart)
        let next = JapanDate.addingDays(7, to: start)
        func inWeek(_ date: Date?) -> Bool {
            guard let date else { return false }
            return date >= start && date < next
        }
        let done = steps.filter { $0.isDone && inWeek($0.doneAt) }.sorted { ($0.doneAt ?? start) < ($1.doneAt ?? start) }
        var days = Array(repeating: 0, count: 7)
        for step in done where step.owner == .me {
            guard let doneAt = step.doneAt else { continue }
            let index = JapanDate.calendar.dateComponents([.day], from: start, to: JapanDate.startOfDay(doneAt)).day ?? 0
            if (0..<7).contains(index) { days[index] += 1 }
        }
        let kajiri = steps.filter { step in
            step.owner == .kajiri && (step.workState == .ready || step.isDone) && (inWeek(step.doneAt) || inWeek(step.log?.createdAt))
        }
        let weekSteps = steps.filter { inWeek($0.doneAt) || inWeek($0.log?.createdAt) }
        return WeekSummary(
            start: start,
            days: days,
            done: done.filter { $0.owner == .me },
            kajiriDone: kajiri.count,
            comeback: done.filter { $0.postponeCount > 0 }.count,
            // 割り直しでできた薪は「あとで」の回数を受け継いでいるが、自分で「いまじゃない」にしたわけではないので数えない
            postponed: steps.filter { !$0.isDone && $0.notBefore != nil && $0.quadrant != .drop }.sorted { $0.postponeCount > $1.postponeCount },
            overrun: TodayPicker.overrun(of: weekSteps),
            thrown: logs.filter { inWeek($0.createdAt) }.count
        )
    }

    /// 例: 11/1〜11/7
    var rangeText: String {
        let calendar = JapanDate.calendar
        return "\(calendar.component(.month, from: start))/\(calendar.component(.day, from: start))〜\(calendar.component(.month, from: end))/\(calendar.component(.day, from: end))"
    }
}

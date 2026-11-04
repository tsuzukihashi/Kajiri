import Foundation

/// 「今日の薪」を決める。全部を見せると固まるので、自分の番の薪から最大3本だけ。
/// 今日すでに片づけた分も数に入れて、片づけたら次が増えすぎないようにする。
@MainActor
enum TodayPicker {
    static let dailyCount = 3

    struct Picks {
        /// 今日片づけた薪（チェック済みで出す）
        let done: [Step]
        /// これから片づける薪
        let open: [Step]

        var isAllDone: Bool { open.isEmpty && !done.isEmpty }
        var isEmpty: Bool { open.isEmpty && done.isEmpty }
    }

    static func pick(from steps: [Step], now: Date, limit: Int) -> Picks {
        let today = JapanDate.startOfDay(now)
        let done = steps
            .filter { isDoneOnDay($0, day: now) }
            .sorted { (lhs: Step, rhs: Step) -> Bool in (lhs.doneAt ?? now) < (rhs.doneAt ?? now) }
        let remaining = max(0, limit - done.count)
        let open = steps
            .filter { isCandidate($0, today: today) }
            .sorted { (lhs: Step, rhs: Step) -> Bool in score(lhs, today: today) < score(rhs, today: today) }
            .prefix(remaining)
        return Picks(done: done, open: Array(open))
    }

    static func isDoneOnDay(_ step: Step, day: Date) -> Bool {
        guard step.isDone, let doneAt = step.doneAt else { return false }
        return JapanDate.isSameDay(doneAt, day)
    }

    /// 自分の番で、まだ終わっていなくて、今日出してよい薪
    static func isCandidate(_ step: Step, today: Date) -> Bool {
        guard isOpenMine(step) else { return false }
        if let notBefore = step.notBefore, notBefore > today { return false }
        // 前の薪（同じ丸太で順番が前の、自分の番の薪）が残っていたら、順番を飛ばさない
        guard let log = step.log else { return true }
        let earlierOpen = log.steps.contains { (other: Step) -> Bool in
            other.order < step.order && isOpenMine(other)
        }
        return !earlierOpen
    }

    private static func isOpenMine(_ step: Step) -> Bool {
        !step.isDone && step.owner == .me && step.quadrant != .drop
    }

    /// 小さいほど先。急ぐ象限 → 締め切りが近い → 丸太の締め切りが近い → 短い
    private static func score(_ step: Step, today: Date) -> Double {
        let quadrant: Double = switch step.quadrant {
        case .today: 0
        case .handoff: 1
        case .stock: 2
        case .drop: 9
        }
        let due = step.due ?? step.log?.deadline
        let days = due.map { max(-30, $0.timeIntervalSince(today) / 86_400) } ?? 365
        return quadrant * 1_000 + days + Double(step.minutes) / 100
    }

    /// 見積もりの何倍かかっているか（直近20本）。分からなければ nil
    static func overrun(of steps: [Step]) -> Double? {
        let ratios = steps
            .filter { $0.isDone && $0.actualMinutes != nil }
            .sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
            .prefix(20)
            .compactMap { step -> Double? in
                guard let actual = step.actualMinutes else { return nil }
                return Double(actual) / Double(max(1, step.minutes))
            }
        guard ratios.count >= 3 else { return nil }
        return min(4, ratios.reduce(0, +) / Double(ratios.count))
    }
}

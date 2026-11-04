import Foundation

/// 通知の予定を決める。何かあるときだけ、次の1回ずつを入れる（開かないあいだに何通も溜めない）。
/// - 朝 8:00: 今日の1本目（自分の番の薪があるときだけ）
/// - 締め切りの前の日 19:00: 丸太の残りの本数
/// - 月曜 8:30: 先週のふりかえり（その週に記録があるか、残っている丸太があるときだけ）
@MainActor
enum NotificationPlanner {
    struct Item: Equatable {
        let id: String
        let title: String
        let body: String
        let fireAt: Date
    }

    static func plan(steps: [Step], logs: [Log], now: Date) -> [Item] {
        var items: [Item] = []
        let calendar = JapanDate.calendar

        // 朝: 明日（いまが8時前なら今日）の8時
        let todayMorning = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        let morning = todayMorning > now ? todayMorning : JapanDate.addingDays(1, to: now).addingTimeInterval(8 * 3600)
        let picks = TodayPicker.pick(from: steps, now: morning, limit: TodayPicker.dailyCount)
        if let first = picks.open.first {
            items.append(Item(
                id: "kajiri.morning",
                title: String(localized: "今日の1本目"),
                body: String(localized: "\(first.title)（\(first.minutes)分）。これだけ持って。"),
                fireAt: morning
            ))
        }

        // 締め切りの前の日の夜
        for log in logs where !log.isFinished {
            guard let deadline = log.deadline else { continue }
            let eve = JapanDate.addingDays(-1, to: deadline).addingTimeInterval(19 * 3600)
            guard eve > now, eve < JapanDate.addingDays(30, to: now) else { continue }
            let left = log.steps.filter { !$0.isDone && $0.quadrant != .drop }.count
            items.append(Item(
                id: "kajiri.deadline.\(log.uuid.uuidString)",
                title: String(localized: "明日は「\(log.title)」の締め切り"),
                body: left > 0
                    ? String(localized: "残りは\(left)本。いちばん小さいのから1本だけ。")
                    : String(localized: "薪は全部片づいている。出すだけだ。"),
                fireAt: eve
            ))
        }

        // 月曜の朝: 先週のふりかえり
        let weekStart = JapanDate.week(containing: now)[0]
        // addingDays は日の始まりにそろえるので、日を決めてから時刻を足す
        let thisMonday = JapanDate.addingDays(1, to: weekStart).addingTimeInterval(8.5 * 3600)
        let nextMonday = thisMonday > now ? thisMonday : JapanDate.addingDays(8, to: weekStart).addingTimeInterval(8.5 * 3600)
        // ふりかえる週（その月曜の前の日曜〜土曜）に記録があるか、まだ片づいていない丸太があるときだけ
        let reviewWeek = WeekSummary.make(steps: steps, logs: logs, weekStart: JapanDate.addingDays(-7, to: JapanDate.week(containing: nextMonday)[0]))
        if !reviewWeek.isEmpty || logs.contains(where: { !$0.isFinished }) {
            items.append(Item(
                id: "kajiri.weekly",
                title: String(localized: "先週のダムを見に行こう"),
                body: String(localized: "カジリが、よかったところと次の一歩を書いて待ってる。"),
                fireAt: nextMonday
            ))
        }
        return items
    }
}

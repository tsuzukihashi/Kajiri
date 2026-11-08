import SwiftUI

/// 月の表に載せるもの（予定の色の点・締め切りの日）と、月の送り方。月の表示と予定のタブの2か所で使う
extension MonthGrid {
    /// 日ごとの予定の色。表に出ている日（前後の月のはみ出しも含む）の分だけ
    @MainActor
    static func dots(month: Date, calendar: CalendarUseCase) -> [String: [Color]] {
        let weeks = weeks(of: month)
        guard let first = weeks.first?.first, let last = weeks.last?.last else { return [:] }
        var dots: [String: [Color]] = [:]
        for event in calendar.events(from: first, to: JapanDate.addingDays(1, to: last)) {
            var day = JapanDate.startOfDay(max(event.start, first))
            let end = event.end.addingTimeInterval(-1)
            while day <= end && day <= last {
                dots[JapanDate.dayString(day), default: []].append(event.color)
                day = JapanDate.addingDays(1, to: day)
            }
        }
        return dots
    }

    /// まだ終わっていない丸太の締め切り（iPhone のカレンダーに入れたものは予定として出るので除く）
    static func openDeadlineLogs(_ logs: [Log]) -> [Log] {
        logs.filter { $0.deadline != nil && $0.deadlineEventID == nil && !$0.isFinished }
    }

    static func deadlineDays(logs: [Log]) -> Set<String> {
        Set(openDeadlineLogs(logs).compactMap { $0.deadline.map(JapanDate.dayString) })
    }

    /// 月を送る。今月に戻ったら今日、ほかの月なら1日を選ぶ
    static func moving(_ month: Date, by months: Int) -> (month: Date, selectedDay: Date) {
        let calendar = JapanDate.calendar
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return (month, month) }
        if calendar.isDate(next, equalTo: AppClock.now, toGranularity: .month) {
            return (next, AppClock.now)
        }
        return (next, calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? next)
    }
}

extension View {
    /// 開いた月をまだ読んでいなければ Google から読む
    func loadsGoogleMonth(_ month: Date) -> some View { modifier(LoadsGoogleMonth(month: month)) }
}

private struct LoadsGoogleMonth: ViewModifier {
    let month: Date
    @Environment(CalendarUseCase.self) private var calendar

    func body(content: Content) -> some View {
        content.task(id: "\(JapanDate.dayString(month))|\(calendar.isGoogleConnected)") {
            let weeks = MonthGrid.weeks(of: month)
            guard let first = weeks.first?.first, let last = weeks.last?.last else { return }
            await calendar.loadGoogle(from: first, to: JapanDate.addingDays(1, to: last))
        }
    }
}

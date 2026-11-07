import Foundation

/// 今日のタブで、いまどのモードにいるか。モードごとに画面の中身を入れかえる（docs/ux-redesign.md）
enum TodayMode: Equatable {
    /// まだ丸太が1本も無い。カジリと「投げて」
    case start
    /// 今日の自分の薪がある。いまの1本が主役
    case next
    /// 今日の自分の薪は無いが、丸太は進んでいる（カジリや仲間の番）
    case kajiri
    /// 今日の分が終わった
    case done

    @MainActor
    static func of(hasLogs: Bool, picks: TodayPicker.Picks, finishedToday: Bool) -> TodayMode {
        guard hasLogs else { return .start }
        if picks.isAllDone || (finishedToday && !picks.done.isEmpty) { return .done }
        if !picks.open.isEmpty { return .next }
        return .kajiri
    }
}

/// いまの1本を始める前に知っておくと楽な、時間の余白。
/// 「次の予定まで、あとどれだけあるか」を1行で言う
@MainActor
struct FreeTimeHint: Equatable {
    enum Kind: Equatable {
        /// 次の予定まで空いている
        case until(title: String, start: Date, minutes: Int)
        /// いま予定の最中
        case during(title: String, end: Date)
        /// 今日はもう予定が無い
        case clear
    }

    let kind: Kind

    static func make(events: [CalendarEvent], now: Date) -> FreeTimeHint? {
        let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
        if let current = timed.first(where: { $0.start <= now && now < $0.end }) {
            return FreeTimeHint(kind: .during(title: current.title, end: current.end))
        }
        if let next = timed.first(where: { $0.start > now }) {
            return FreeTimeHint(kind: .until(title: next.title, start: next.start, minutes: Int(next.start.timeIntervalSince(now) / 60)))
        }
        return timed.isEmpty ? nil : FreeTimeHint(kind: .clear)
    }

    var text: String {
        switch kind {
        case let .until(title, start, minutes):
            String(localized: "\(CalendarUseCase.clock(start)) \(title) まで、\(Self.duration(minutes))空いています")
        case let .during(title, end):
            String(localized: "いまは \(title)（〜\(CalendarUseCase.clock(end))）")
        case .clear:
            String(localized: "今日はこのあと予定がありません")
        }
    }

    static func duration(_ minutes: Int) -> String {
        let value = max(0, minutes)
        if value >= 60 {
            return value % 60 == 0
                ? String(localized: "\(value / 60)時間")
                : String(localized: "\(value / 60)時間\(value % 60)分")
        }
        return String(localized: "\(value)分")
    }
}

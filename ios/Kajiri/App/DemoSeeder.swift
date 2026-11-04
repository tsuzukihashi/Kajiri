#if DEBUG
import EventKit
import Foundation

/// 確かめる・デモを撮るとき用（DEBUG ビルドで、起動引数 -seedDemo を付けたときだけ）。
/// シミュレータのカレンダーに、今日から1週間ぶんの見本の予定を入れる。
/// 入れた予定はメモに印を付けておき、2回目からは入れない。App Store 版には入らない。
@MainActor
enum DemoSeeder {
    static let mark = "kajiri-demo"

    static func seedIfAsked() async {
        guard ProcessInfo.processInfo.arguments.contains("-seedDemo") else { return }
        let store = EKEventStore()
        let granted: Bool = await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, _ in continuation.resume(returning: granted) }
        }
        guard granted, let calendar = store.defaultCalendarForNewEvents else { return }
        let today = JapanDate.startOfDay(.now)
        let range = store.predicateForEvents(withStart: today, end: JapanDate.addingDays(14, to: today), calendars: nil)
        guard !store.events(matching: range).contains(where: { $0.notes == mark }) else { return }

        let samples: [(day: Int, hour: Int, minute: Int, minutes: Int, title: String, location: String)] = [
            (0, 9, 30, 30, "朝会", ""),
            (0, 13, 0, 60, "歯医者", "駅前デンタル"),
            (0, 17, 0, 60, "新製品の発表", "本社 会議室A"),
            (1, 19, 0, 90, "ジム", ""),
            (2, 12, 0, 60, "母とランチ", "銀座"),
            (3, 10, 0, 60, "1on1", ""),
            (5, 0, 0, 0, "引っ越し", ""),
            (9, 0, 0, 0, "結婚記念日", ""),
        ]
        for sample in samples {
            let event = EKEvent(eventStore: store)
            event.calendar = calendar
            event.title = sample.title
            event.location = sample.location.isEmpty ? nil : sample.location
            event.notes = mark
            let day = JapanDate.addingDays(sample.day, to: today)
            if sample.minutes == 0 {
                event.isAllDay = true
                event.startDate = day
                event.endDate = day
            } else {
                let start = JapanDate.calendar.date(bySettingHour: sample.hour, minute: sample.minute, second: 0, of: day) ?? day
                event.startDate = start
                event.endDate = start.addingTimeInterval(TimeInterval(sample.minutes * 60))
            }
            try? store.save(event, span: .thisEvent, commit: false)
        }
        try? store.commit()
    }
}
#endif

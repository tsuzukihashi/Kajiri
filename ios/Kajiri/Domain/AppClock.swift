import Foundation

/// いまの時刻。画面と記録はここから取る。
/// DEBUG ビルドで起動引数 `-demoHour 10` を付けたときだけ、今日の 10:15 から時計が進む（夜中でも日中の画面を確かめ・撮るため）。
/// `-demoDays 10` で日もずらせる
enum AppClock {
    static var now: Date { Date.now.addingTimeInterval(offset) }

    private static let offset: TimeInterval = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let launched = Date.now
        var target = launched
        // -demoDays 10: 10日先の日にする（2桁の日付の見た目を確かめるため）
        if let index = arguments.firstIndex(of: "-demoDays"), index + 1 < arguments.count, let days = Int(arguments[index + 1]) {
            target = JapanDate.calendar.date(byAdding: .day, value: days, to: target) ?? target
        }
        if let index = arguments.firstIndex(of: "-demoHour"), index + 1 < arguments.count, let hour = Int(arguments[index + 1]) {
            target = JapanDate.calendar.date(bySettingHour: hour, minute: 15, second: 0, of: target) ?? target
        }
        return target.timeIntervalSince(launched)
        #endif
        return 0
    }()
}

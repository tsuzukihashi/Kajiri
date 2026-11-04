import Foundation

/// いまの時刻。画面と記録はここから取る。
/// DEBUG ビルドで起動引数 `-demoHour 10` を付けたときだけ、今日の 10:15 から時計が進む（夜中でも日中の画面を確かめ・撮るため）
enum AppClock {
    static var now: Date { Date.now.addingTimeInterval(offset) }

    private static let offset: TimeInterval = {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-demoHour"), index + 1 < arguments.count, let hour = Int(arguments[index + 1]) {
            let launched = Date.now
            let target = JapanDate.calendar.date(bySettingHour: hour, minute: 15, second: 0, of: launched) ?? launched
            return target.timeIntervalSince(launched)
        }
        #endif
        return 0
    }()
}

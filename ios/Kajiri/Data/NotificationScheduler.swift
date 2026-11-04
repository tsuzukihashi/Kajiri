import Foundation
import UserNotifications

/// 端末の通知の口。Preview とテストでは何もしない偽物を差し込む
@MainActor
protocol NotificationSchedulerProtocol: AnyObject {
    /// 通知を出してよいか、まだ聞いていなければ聞く
    func requestIfNeeded() async
    /// Kajiri の通知を、渡したものだけに入れ替える
    func replace(with items: [NotificationPlanner.Item]) async
}

@MainActor
final class NotificationScheduler: NotificationSchedulerProtocol {
    private let center = UNUserNotificationCenter.current()

    func requestIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    func replace(with items: [NotificationPlanner.Item]) async {
        let settings = await center.notificationSettings()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("kajiri.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
        for item in items {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            var components = JapanDate.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireAt)
            components.timeZone = JapanDate.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: item.id, content: content, trigger: trigger))
        }
    }
}

#if DEBUG
@MainActor
final class MockNotificationScheduler: NotificationSchedulerProtocol {
    private(set) var scheduled: [NotificationPlanner.Item] = []
    func requestIfNeeded() async {}
    func replace(with items: [NotificationPlanner.Item]) async { scheduled = items }
}
#endif

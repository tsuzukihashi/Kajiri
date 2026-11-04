import EventKit
import Foundation
import UIKit

/// 予定を作る・直す画面（Apple の標準の画面）に渡すもの
struct EventEditorRequest: Identifiable {
    let id = UUID()
    let store: EKEventStore
    let event: EKEvent
}

/// 新しく入れる予定の下書き
struct EventDraft {
    let title: String
    let start: Date
    let isAllDay: Bool
    let notes: String
}

/// iPhone のカレンダーを読み書きする口。Preview とテストでは偽物を差し込む。
@MainActor
protocol CalendarRepositoryProtocol: AnyObject {
    func access() -> CalendarAccess
    func requestAccess() async -> CalendarAccess
    func events(from: Date, to: Date) -> [CalendarEvent]
    /// すでにある予定を直す画面。偽物では nil
    func editorRequest(for event: CalendarEvent) -> EventEditorRequest?
    /// 新しい予定を入れる画面。偽物では nil
    func newEventRequest(draft: EventDraft) -> EventEditorRequest?
    /// カレンダーの中身が変わったら呼ぶ（ほかのアプリで予定を足した・同期した など）
    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void)
}

/// 本物。設定に入れたカレンダー（Google・iCloud・Outlook など）を EventKit でまとめて読む。
/// 予定は iPhone のカレンダーにだけ置き、Kajiri には写さない。
@MainActor
final class EventKitCalendarRepository: CalendarRepositoryProtocol {
    private let store = EKEventStore()
    /// 最後に読んだ予定（直す画面を開くときに使う）
    private var loaded: [String: EKEvent] = [:]
    private var observer: NSObjectProtocol?

    func access() -> CalendarAccess {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async -> CalendarAccess {
        let granted: Bool = await withCheckedContinuation { continuation in
            store.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        if granted { store.reset() }
        return granted ? .granted : access()
    }

    func events(from: Date, to: Date) -> [CalendarEvent] {
        guard access() == .granted else { return [] }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: nil)
        return store.events(matching: predicate).map { event in
            let value = Self.value(of: event)
            loaded[value.id] = event
            return value
        }
    }

    func editorRequest(for event: CalendarEvent) -> EventEditorRequest? {
        let found = loaded[event.id] ?? store.event(withIdentifier: event.eventIdentifier)
        guard let found else { return nil }
        return EventEditorRequest(store: store, event: found)
    }

    func newEventRequest(draft: EventDraft) -> EventEditorRequest? {
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.isAllDay = draft.isAllDay
        event.startDate = draft.start
        event.endDate = draft.isAllDay ? draft.start : draft.start.addingTimeInterval(60 * 60)
        event.notes = draft.notes.isEmpty ? nil : draft.notes
        event.calendar = store.defaultCalendarForNewEvents
        return EventEditorRequest(store: store, event: event)
    }

    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
    }

    private static func value(of event: EKEvent) -> CalendarEvent {
        var red: CGFloat = 0.5, green: CGFloat = 0.5, blue: CGFloat = 0.5, alpha: CGFloat = 1
        if let color = event.calendar?.cgColor {
            UIColor(cgColor: color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }
        let identifier = event.eventIdentifier ?? event.calendarItemIdentifier
        let start = event.startDate ?? .now
        return CalendarEvent(
            id: "\(identifier)|\(Int(start.timeIntervalSince1970))",
            eventIdentifier: identifier,
            title: event.title ?? String(localized: "（名前のない予定）"),
            start: start,
            end: event.endDate ?? start,
            isAllDay: event.isAllDay,
            location: event.location ?? "",
            calendarTitle: event.calendar?.title ?? "",
            red: Double(red), green: Double(green), blue: Double(blue)
        )
    }
}

#if DEBUG
/// Preview 用。決まった予定を返す
@MainActor
final class MockCalendarRepository: CalendarRepositoryProtocol {
    private let state: CalendarAccess
    private let stored: [CalendarEvent]

    init(access: CalendarAccess, events: [CalendarEvent]) {
        self.state = access
        self.stored = events
    }

    func access() -> CalendarAccess { state }
    func requestAccess() async -> CalendarAccess { state }
    func events(from: Date, to: Date) -> [CalendarEvent] {
        stored.filter { $0.start < to && $0.end > from }
    }
    func editorRequest(for event: CalendarEvent) -> EventEditorRequest? { nil }
    func newEventRequest(draft: EventDraft) -> EventEditorRequest? { nil }
    func observeChanges(_ handler: @escaping @MainActor @Sendable () -> Void) {}
}
#endif

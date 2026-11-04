import Foundation
import Observation

/// この先2週間の予定をカジリに見てもらい、準備が要りそうなものを選んでもらう
@MainActor
@Observable
final class PrepScanViewModel {
    enum Phase: Equatable {
        case idle
        case scanning
        case result(PrepResult)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// 見てもらった予定（選ばれた予定の名前と日時を出すため）
    private(set) var scanned: [String: CalendarEvent] = [:]

    func scan(calendar: CalendarUseCase, linked: Set<String>, now: Date) async {
        let events = calendar.upcomingForPrep(now: now, excluding: linked)
        guard !events.isEmpty else {
            phase = .result(PrepResult(picks: [], comment: String(localized: "この先2週間に、まだ丸太にしていない予定はないな。")))
            return
        }
        phase = .scanning
        scanned = Dictionary(events.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        do {
            phase = .result(try await calendar.scanPrep(events: events, now: now))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func event(for pick: PrepPick) -> CalendarEvent? {
        scanned[pick.eventID]
    }
}

import Foundation
import Observation

/// 丸太を投げる → カジリがかじる → 結果を見て「これでいこう」
@MainActor
@Observable
final class ThrowViewModel {
    enum Phase: Equatable {
        case editing
        case splitting
        case result(DecomposeResult)
        case failed(String)
    }

    var memo: String
    /// カレンダーの予定から投げたなら、その予定
    let sourceEventID: String?
    private(set) var phase: Phase = .editing
    /// カジリがカレンダーに入れた予定
    private(set) var placement = EventPlacement.empty

    init(memo: String, sourceEventID: String?) {
        self.memo = memo
        self.sourceEventID = sourceEventID
    }

    var canSplit: Bool {
        !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && phase != .splitting
    }

    func split(useCase: LogUseCase, calendar: CalendarUseCase) async {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        phase = .splitting
        do {
            let result = try await useCase.decompose(memo: text, now: AppClock.now)
            // 予定から投げたメモには、もうある予定の名前と日が入っている。入れ直さない
            if sourceEventID == nil {
                placement = await calendar.place(result.events ?? [], now: AppClock.now)
            }
            phase = .result(result)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func save(useCase: LogUseCase) {
        guard case let .result(result) = phase, !result.steps.isEmpty else { return }
        useCase.save(result, memo: memo, sourceEventID: sourceEventID, now: AppClock.now)
    }

    func undo(_ event: PlacedEvent, calendar: CalendarUseCase) {
        placement = calendar.undo(event, in: placement)
    }

    /// 書き直すなら、入れた予定も取り消す（投げ直すと二重に入る）
    func backToEditing(calendar: CalendarUseCase) {
        calendar.undoAll(in: placement)
        placement = .empty
        phase = .editing
    }
}

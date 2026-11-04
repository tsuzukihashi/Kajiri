import Foundation
import Observation

/// 週のふりかえり。週を選び、記録をまとめ、カジリに3つの欄を書いてもらう
@MainActor
@Observable
final class WeeklyViewModel {
    enum Phase: Equatable {
        case idle
        case writing
        case written(WeeklyResult)
        case failed(String)
    }

    private(set) var weekStart: Date
    private(set) var phase: Phase = .idle

    init(now: Date) {
        weekStart = JapanDate.week(containing: now)[0]
    }

    func summary(useCase: LogUseCase) -> WeekSummary {
        useCase.weekSummary(weekStart: weekStart)
    }

    /// 前の週・次の週へ（来週より先には行かない）
    func move(_ weeks: Int, useCase: LogUseCase, now: Date) {
        let next = JapanDate.addingDays(weeks * 7, to: weekStart)
        guard next <= JapanDate.week(containing: now)[0] else { return }
        weekStart = next
        load(useCase: useCase)
    }

    func canMoveForward(now: Date) -> Bool {
        weekStart < JapanDate.week(containing: now)[0]
    }

    /// 前に書いてもらったものがあれば出す
    func load(useCase: LogUseCase) {
        if let saved = useCase.savedReview(summary(useCase: useCase)) {
            phase = .written(saved)
        } else {
            phase = .idle
        }
    }

    func write(useCase: LogUseCase) async {
        phase = .writing
        do {
            phase = .written(try await useCase.review(summary(useCase: useCase)))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

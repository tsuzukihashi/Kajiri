import Foundation
import Observation

/// 「あとで」の理由を聞いて、理由ごとに違う直し方をする（フォッグの行動モデル）
/// - まだ大きい → カジリがもっと小さく割り直す
/// - いまじゃない → 明日まで出さない
/// - 気が乗らない → 川に流すか、仲間に頼む
@MainActor
@Observable
final class LaterViewModel {
    enum Phase: Equatable {
        case choosing
        case resplitting
        case resplit(ResplitResult)
        case failed(String)
    }

    private(set) var phase: Phase = .choosing

    func resplit(_ step: Step, useCase: LogUseCase) async {
        phase = .resplitting
        do {
            phase = .resplit(try await useCase.resplit(step, now: .now))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func accept(_ step: Step, useCase: LogUseCase) {
        guard case let .resplit(result) = phase else { return }
        useCase.apply(result, replacing: step, now: .now)
    }
}

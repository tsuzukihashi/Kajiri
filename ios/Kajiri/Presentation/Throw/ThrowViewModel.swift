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

    init(memo: String, sourceEventID: String?) {
        self.memo = memo
        self.sourceEventID = sourceEventID
    }

    var canSplit: Bool {
        !memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && phase != .splitting
    }

    func split(useCase: LogUseCase) async {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        phase = .splitting
        do {
            phase = .result(try await useCase.decompose(memo: text, now: .now))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func save(useCase: LogUseCase) {
        guard case let .result(result) = phase else { return }
        useCase.save(result, memo: memo, sourceEventID: sourceEventID, now: .now)
    }

    func backToEditing() {
        phase = .editing
    }
}

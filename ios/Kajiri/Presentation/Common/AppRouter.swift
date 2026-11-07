import Foundation
import Observation

/// どのタブを開いているか・各タブでどこまで進んだか・アプリ全体で1つだけ出すシート（投げる・ふりかえり）
@MainActor
@Observable
final class AppRouter {
    enum Tab: Hashable {
        case today
        case logs
        case plan
    }

    var tab: Tab = .today
    var todayPath: [Route] = []
    var logsPath: [Route] = []
    var planPath: [Route] = []
    var throwRequest: ThrowRequest?
    var showsWeekly = false

    func throwNew() {
        throwRequest = ThrowRequest(memo: "", sourceEventID: nil)
    }

    /// Siri・共有シートから投げられたとき。今日のタブに戻してから開く
    func throwFromOutside(memo: String) {
        tab = .today
        todayPath = []
        throwRequest = ThrowRequest(memo: memo, sourceEventID: nil)
    }
}

import Foundation
import Observation

/// どのタブを開いているか・各タブでどこまで進んだか・アプリ全体で1つだけ出すシート（投げる・ふりかえり）
@MainActor
@Observable
final class AppRouter {
    /// 画面は「今日」1つ。丸太の一覧・予定・設定は、ここから開いて、戻ると今日に帰る
    var todayPath: [Route] = []
    var throwRequest: ThrowRequest?
    var showsWeekly = false

    func throwNew() {
        throwRequest = ThrowRequest(memo: "", sourceEventID: nil)
    }

    /// Siri・共有シートから投げられたとき。今日のタブに戻してから開く
    func throwFromOutside(memo: String) {
        todayPath = []
        throwRequest = ThrowRequest(memo: memo, sourceEventID: nil)
    }
}

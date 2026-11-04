import Foundation
import Observation

/// Siri・アクションボタン・ショートカットから届いたものを、ホームに渡す受け口。
/// App Intent はシステムが作るので、アプリ全体で1つの受け口を共有する
@MainActor
@Observable
final class IntentInbox {
    static let shared = IntentInbox()

    /// 投げるシートに入れておくメモ（空文字なら、空のシートを開く）
    var pendingThrow: String?
}

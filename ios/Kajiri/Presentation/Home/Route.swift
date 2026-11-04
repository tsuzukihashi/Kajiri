import Foundation

/// ホームの NavigationStack で行ける画面。遷移はすべてここに集める
enum Route: Hashable {
    /// この1本だけ
    case focus(UUID)
    /// カジリが運んできたものを受け取る
    case handoff(UUID)
    /// 4象限（川辺の地図）
    case matrix
    /// 月の予定と、カジリに準備を見てもらう
    case month
}

import Foundation

/// 丸太を投げるシートを開くときの中身。予定から投げるときは、メモの下書きと予定が入っている
struct ThrowRequest: Identifiable {
    let id = UUID()
    let memo: String
    let sourceEventID: String?
}

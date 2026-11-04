import Foundation

/// 共有シート（Kajiri に投げる）から届いたメモの置き場。アプリと共有の拡張の両方から使う（App Group）
enum SharedInbox {
    static let groupID = "group.com.tsuzukit.Kajiri"
    private static let key = "pendingMemos"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    /// 拡張から: メモを1つ置く
    static func push(_ memo: String) {
        let text = memo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let defaults else { return }
        var memos = defaults.stringArray(forKey: key) ?? []
        memos.append(String(text.prefix(4_000)))
        defaults.set(memos, forKey: key)
    }

    /// アプリから: いちばん古いメモを1つ取り出す（残りは次に開いたとき）
    static func pop() -> String? {
        guard let defaults, var memos = defaults.stringArray(forKey: key), !memos.isEmpty else { return nil }
        let first = memos.removeFirst()
        defaults.set(memos, forKey: key)
        return first
    }
}

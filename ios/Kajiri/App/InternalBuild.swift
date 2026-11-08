import Observation
import StoreKit

/// 確かめる人だけが使う入口（設定の Debug）を出してよい版か。
/// Xcode から入れたものと TestFlight では出し、App Store 版では出さない。判定できなかったら出さない
@MainActor
@Observable
final class InternalBuild {
    static let shared = InternalBuild()

    private(set) var isEnabled: Bool

    private init() {
        #if DEBUG
        isEnabled = true
        #else
        isEnabled = false
        #endif
    }

    /// 起動時に1回
    func resolve() async {
        #if !DEBUG
        guard case let .verified(transaction) = try? await AppTransaction.shared else { return }
        isEnabled = transaction.environment == .sandbox || transaction.environment == .xcode
        #endif
    }
}

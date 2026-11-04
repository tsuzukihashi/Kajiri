import FirebaseAppCheck
import FirebaseCore
import FirebaseFunctions
import Foundation

/// Firebase の初期化。中継サーバ（Functions）を呼ぶときは必ず App Check のトークンが付く。
enum FirebaseSetup {
    /// Functions の地域（functions/src/index.ts の setGlobalOptions と合わせる）
    static let region = "asia-northeast1"

    @MainActor
    static func configure() {
        // リポジトリを取ってきたばかりで GoogleService-Info.plist が無いときは、落とさずに起動する
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else { return }

        AppCheck.setAppCheckProviderFactory(KajiriAppCheckProviderFactory())
        FirebaseApp.configure()

        #if DEBUG
        // 手元のエミュレータ（cd functions && npm run serve）につなぐときは、起動引数に -useFunctionsEmulator を付ける
        if ProcessInfo.processInfo.arguments.contains("-useFunctionsEmulator") {
            Functions.functions(region: region).useEmulator(withHost: "localhost", port: 5001)
        }
        #endif
    }
}

/// 実機は App Attest、シミュレータはデバッグ用の提供元を使う。
final class KajiriAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> (any AppCheckProvider)? {
        #if targetEnvironment(simulator)
        // シミュレータでは App Attest が使えない。起動時にログに出るデバッグトークンを
        // Firebase コンソールの App Check に登録する。デバッグトークンは秘密なので、どこにもコミットしない
        return AppCheckDebugProvider(app: app)
        #else
        return AppAttestProvider(app: app)
        #endif
    }
}

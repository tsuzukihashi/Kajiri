import Foundation

/// オンボーディングの1ページ。はじめて開いた人が知りたいのは「何をしてくれるアプリか」と「どう使うか」だけなので、3ページで言い切る
nonisolated struct OnboardingPage: Identifiable, Equatable, Sendable {
    let id: Int
    /// 水彩の薪の絵（Assets の名前）
    let image: String
    let title: String
    let body: String

    static let all: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            image: "onboarding_split",
            title: String(localized: "大きいことは、かじって小さく"),
            body: String(localized: "手がつかないのは、やることが大きいから。カジリが、今すぐ手が動く大きさ（15分くらい）に分けます。")
        ),
        OnboardingPage(
            id: 1,
            image: "onboarding_bite",
            title: String(localized: "雑なメモを、投げるだけ"),
            body: String(localized: "「引っ越し。粗大ゴミどうしよう」くらいで大丈夫。返信の下書きや調べものは、カジリが代わりに作ります。")
        ),
        OnboardingPage(
            id: 2,
            image: "onboarding_one",
            title: String(localized: "今日は、1本だけ見る"),
            body: String(localized: "全部は見せません。いまやる1本と［できた］だけ。終わったら、次の1本が出ます。")
        ),
    ]
}

/// オンボーディングを出すか。見終わったら端末に覚える。設定の Debug から、もう一度見られる
enum OnboardingGate {
    static let seenKey = "hasSeenOnboarding"

    /// スクショやデモ動画を撮るときは出さない（-showOnboarding を付けたときだけ出す）
    static var isSuppressedByLaunchArguments: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-showOnboarding") { return false }
        return arguments.contains("-storeShots") || arguments.contains("-seedDemo") || arguments.contains("-skipOnboarding")
    }
}

import AppIntents
import Foundation

/// 「カジリに投げる」。Siri・アクションボタン・ショートカットから、メモを入れた投げるシートを開く。
/// 分けるのはアプリの中で（結果を見て「これでいこう」を押してもらう）
struct ThrowLogIntent: AppIntent {
    static let title: LocalizedStringResource = "カジリに投げる"
    static let description = IntentDescription("気になっていることを、そのままカジリに投げます。カジリがすぐ手が動く大きさにかじります。")
    static let openAppWhenRun = true

    @Parameter(title: "メモ", requestValueDialog: "何が気になってる？")
    var memo: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentInbox.shared.pendingThrow = memo?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .result()
    }
}

/// 「今日の1本目」。アプリを開いて、今日いちばん早い空き時間を見せる
struct OpenTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "今日の薪を見る"
    static let description = IntentDescription("Kajiri を開いて、今日の薪と予定を見ます。")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct KajiriShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ThrowLogIntent(),
            phrases: [
                "\(.applicationName)に投げる",
                "\(.applicationName)にかじってもらう",
            ],
            shortTitle: "カジリに投げる",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: OpenTodayIntent(),
            phrases: [
                "\(.applicationName)で今日の薪を見る",
            ],
            shortTitle: "今日の薪",
            systemImageName: "calendar"
        )
    }
}

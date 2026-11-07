import XCTest

/// App Store のスクリーンショットを撮る（fastlane snapshot から流す）。
/// アプリを -storeShots で起動すると、メモリの中の見本データと、決まった答えを返す中継サーバで動く（App/StoreShots.swift）。
/// -seedDemo でシミュレータのカレンダーに見本の予定を入れ、-demoHour 10 で時計を 10:15 にする。
final class ScreenshotTests: XCTestCase {
    @MainActor
    func testCaptureAppStoreScreenshots() {
        continueAfterFailure = false
        let common = ["-storeShots", "-seedDemo", "-demoHour", "10"]

        func launch(_ extra: [String]) -> XCUIApplication {
            let app = XCUIApplication()
            setupSnapshot(app, waitForAnimations: true)
            app.launchArguments += common + extra
            app.launch()
            return app
        }

        func require(_ element: XCUIElement, _ name: String) {
            guard element.waitForExistence(timeout: 15) else {
                snapshot("ERROR_\(name)")
                XCTFail("\(name) が出ない")
                return
            }
        }

        // 1. 雑なメモを投げると、すぐ手が動く一歩に分かれる
        var app = launch(["-demoThrow", "確定申告、去年ギリギリで地獄だった。今年は早めにやりたい。医療費の領収書は箱に入ってる"])
        let split = app.buttons["カジリに渡す"]
        require(split, "カジリに渡す")
        split.tap()
        require(app.buttons["これでいこう"], "分けた結果")
        snapshot("01_split")
        app.terminate()

        // 2. 今日のタブは、いまの1本が主役
        app = launch([])
        require(app.staticTexts["はじめる"], "いまの1本")
        snapshot("02_today")
        app.terminate()

        // 3. 下書きと調べものは、カジリが同時に
        app = launch(["-storeShot", "handoff"])
        require(app.staticTexts["年末調整、書くところは3つだけ"], "カジリの下書き")
        snapshot("03_handoff")
        app.terminate()

        // 4. 押したら、この1本だけ
        app = launch(["-storeShot", "focus"])
        require(app.staticTexts["スライドの見出しを3つ書く"], "この1本だけ")
        snapshot("04_focus")
        app.terminate()

        // 5. 予定のすき間に、今日の薪
        app = launch(["-storeShot", "plan"])
        require(app.staticTexts["今日の流れ"], "今日の流れ")
        snapshot("05_plan")
        app.terminate()

        // 6. 予定から、準備が要るものに気づく
        app = launch(["-storeShot", "month"])
        let scan = app.buttons["カジリに見てもらう"]
        require(scan, "カジリに見てもらう")
        scan.tap()
        require(app.buttons["この準備をかじってもらう"].firstMatch, "準備が要りそうな予定")
        snapshot("06_prep")
        app.terminate()

        // 7. 週のふりかえり
        app = launch(["-storeShot", "weekly"])
        let review = app.buttons["カジリにふりかえってもらう"]
        require(review, "カジリにふりかえってもらう")
        review.tap()
        require(app.staticTexts["毎日ひとかじり。それで山は小さくなる。"], "ふりかえり")
        snapshot("07_weekly")
        app.terminate()
    }
}

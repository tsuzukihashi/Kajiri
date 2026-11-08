import XCTest

/// デモ動画を撮るときに、画面を決まった順で動かす（ふだんのテストでは流さない）。
/// 本番の中継サーバ（Claude）につないで動かすので、分ける・作るの待ち時間は本物。録画は外で simctl io recordVideo を回す。
/// 区切りごとに「DEMO_MARK 名前 時刻」をログに出す。録画の開始時刻と突き合わせて、字幕の位置と速める区間を決める。
/// 流し方: -only-testing:KajiriUITests/DemoVideoTests（アプリは消して入れ直し、まっさらな状態から始める）
final class DemoVideoTests: XCTestCase {
    @MainActor
    func testRecordDemoFlow() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += [
            "-seedDemo", "-demoHour", "10",
            "-demoThrow", "確定申告、去年ギリギリで地獄だった。今年は早めにやりたい。医療費の領収書は箱に入ってる", "-demoThrowAfter", "5",
        ]

        func mark(_ name: String) {
            print("DEMO_MARK \(name) \(Date().timeIntervalSince1970)")
        }
        func pause(_ seconds: Double) {
            Thread.sleep(forTimeInterval: seconds)
        }
        func tap(_ element: XCUIElement, _ name: String, timeout: Double) {
            guard element.waitForExistence(timeout: timeout) else {
                XCTFail("\(name) が出ない")
                return
            }
            element.tap()
        }
        // 通知の許可は、出たら許す（ホーム画面側のアラート）
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        func allowIfAsked(_ seconds: Double) {
            for label in ["許可", "Allow"] {
                let button = springboard.alerts.buttons[label]
                if button.waitForExistence(timeout: seconds) {
                    pause(1.5)
                    button.tap()
                    return
                }
            }
        }

        app.launch()
        mark("start")
        // 1. まだ何も無い今日。少し見せてから、投げるシートが開く（-demoThrowAfter）
        let split = app.buttons["カジリに渡す"]
        XCTAssertTrue(split.waitForExistence(timeout: 20))
        mark("sheet")
        pause(3)
        split.tap()
        mark("splitting")
        // 2. カジリがかじった結果
        let accept = app.buttons["これでいこう"]
        XCTAssertTrue(accept.waitForExistence(timeout: 120))
        mark("result")
        pause(5)
        app.swipeUp()
        pause(3)
        accept.tap()
        mark("accepted")
        allowIfAsked(8)
        pause(3)
        // 3. 今日の1本
        // 「はじめる」は NavigationLink なので、ボタンではなく文字で探す
        let start = app.staticTexts["はじめる"]
        XCTAssertTrue(start.waitForExistence(timeout: 20))
        mark("today")
        pause(5)
        start.tap()
        mark("focus")
        pause(4)
        tap(app.buttons["できた"], "できた", timeout: 10)
        mark("done1")
        pause(4)
        // 4. カジリから届くのを待って、受け取る
        let arrived = app.staticTexts["見て、よければ使うだけ"].firstMatch
        XCTAssertTrue(arrived.waitForExistence(timeout: 240))
        mark("arrived")
        app.swipeUp()
        pause(3)
        arrived.tap()
        mark("handoff")
        pause(6)
        app.swipeUp()
        pause(3)
        tap(app.buttons["受け取った"], "受け取った", timeout: 10)
        mark("received")
        pause(3)
        // 5. 予定のタブ
        tap(app.tabBars.buttons["予定"].firstMatch, "予定のタブ", timeout: 10)
        mark("plan")
        pause(5)
        app.swipeUp()
        pause(4)
        app.swipeDown()
        pause(1)
        // 6. 準備が要りそうな予定を探す
        tap(app.buttons["ほかの操作"], "ほかの操作", timeout: 10)
        pause(1)
        tap(app.buttons["準備が要りそうな予定を探す"], "準備を探す", timeout: 10)
        pause(2)
        tap(app.buttons["カジリに見てもらう"], "カジリに見てもらう", timeout: 10)
        mark("scanning")
        let prep = app.buttons["この準備をかじってもらう"].firstMatch
        XCTAssertTrue(prep.waitForExistence(timeout: 120))
        mark("prep")
        pause(6)
        app.swipeDown(velocity: .fast)
        pause(2)
        // 7. 丸太のタブと4象限
        tap(app.tabBars.buttons["丸太"].firstMatch, "丸太のタブ", timeout: 10)
        mark("logs")
        pause(4)
        tap(app.buttons["4象限"], "4象限", timeout: 10)
        mark("matrix")
        pause(5)
        mark("end")
    }
}

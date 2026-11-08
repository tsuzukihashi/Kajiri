import XCTest

/// 今日の分が終わった画面で「今日はおしまい」を押したら、画面が変わるか（押しても何も起きない、を二度と作らない）
final class TodayFinishTests: XCTestCase {
    @MainActor
    func testFinishChangesTheScreen() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-storeShots", "-storeShotsState", "done"]
        app.launch()

        let finish = app.buttons["今日はおしまい"]
        XCTAssertTrue(finish.waitForExistence(timeout: 20))
        finish.tap()

        XCTAssertTrue(app.staticTexts["今日はここまで"].waitForExistence(timeout: 5), "押したら「今日はここまで」の札が出る")
        XCTAssertTrue(app.staticTexts["おつかれさま。また明日。"].exists, "カジリの言葉が変わる")
        XCTAssertFalse(app.buttons["今日はおしまい"].exists, "押したボタンは消える")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "closed"
        shot.lifetime = .keepAlways
        add(shot)
        // 続ける道は残す。やれる薪が残っていれば「もう1本だけ」、無ければ「新しく投げる」
        let more = app.buttons["やっぱり、もう1本だけ"]
        let throwNew = app.buttons["新しく投げる"]
        XCTAssertTrue(more.exists || throwNew.exists, "続ける道が残っている")
        if more.exists {
            more.tap()
            XCTAssertTrue(app.staticTexts["今日はここまで"].waitForNonExistence(timeout: 5), "もう1本だけを押したら、次の薪の画面に移る")
        }
    }
}

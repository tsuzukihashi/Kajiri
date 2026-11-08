import XCTest

/// はじめて開いたときのオンボーディングを最後まで進めると、今日に戻る。設定の Debug からもう一度出せる
final class OnboardingTests: XCTestCase {
    @MainActor
    func testWalkThroughAndReplay() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-storeShots", "-showOnboarding"]
        app.launch()

        XCTAssertTrue(app.staticTexts["大きいことは、かじって小さく"].waitForExistence(timeout: 20), "1ページ目が出る")
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.staticTexts["雑なメモを、投げるだけ"].waitForExistence(timeout: 5), "2ページ目へ進む")
        app.buttons["次へ"].tap()
        XCTAssertTrue(app.staticTexts["今日は、1本だけ見る"].waitForExistence(timeout: 5), "3ページ目へ進む")
        XCTAssertFalse(app.buttons["スキップ"].exists, "最後のページにはスキップを出さない")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "lastPage"
        shot.lifetime = .keepAlways
        add(shot)
        app.buttons["あとで"].tap()
        XCTAssertTrue(app.buttons["設定"].waitForExistence(timeout: 10), "閉じると今日に戻る")

        // 設定の Debug から、もう一度見られる
        app.buttons["設定"].tap()
        let replay = app.buttons["オンボーディングをもう一度見る"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        replay.tap()
        XCTAssertTrue(app.staticTexts["大きいことは、かじって小さく"].waitForExistence(timeout: 5), "もう一度、1ページ目から出る")
        app.buttons["スキップ"].tap()
        XCTAssertTrue(app.staticTexts["大きいことは、かじって小さく"].waitForNonExistence(timeout: 5), "スキップで閉じる")
    }
}

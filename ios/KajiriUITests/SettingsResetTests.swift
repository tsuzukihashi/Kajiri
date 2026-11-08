import XCTest

/// 設定の Debug で「これまでのデータをすべて消す」と、今日のいちばん初めに戻る
final class SettingsResetTests: XCTestCase {
    @MainActor
    func testDeleteAllReturnsToStart() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-storeShots"]
        app.launch()

        let gear = app.buttons["設定"]
        XCTAssertTrue(gear.waitForExistence(timeout: 20))
        gear.tap()

        let delete = app.buttons["これまでのデータをすべて消す"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5), "Debug の消すボタンがある")
        delete.tap()
        let confirm = app.buttons["すべて消す"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "消す前に確かめる")
        confirm.tap()

        XCTAssertTrue(app.buttons["最初の丸太を投げる"].waitForExistence(timeout: 10), "消したら今日のいちばん初めに戻る")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "afterReset"
        shot.lifetime = .keepAlways
        add(shot)
    }
}

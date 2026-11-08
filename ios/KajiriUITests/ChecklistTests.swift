import XCTest

/// カジリが作ったチェックリストを、押してチェックできるか・メモを書いてキーボードを下げられるか
final class ChecklistTests: XCTestCase {
    @MainActor
    func testCheckAndWriteNote() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-storeShots", "-storeShot", "checklist"]
        app.launch()

        // 見本は2つ確かめたところから始まる
        XCTAssertTrue(app.staticTexts["2"].waitForExistence(timeout: 20))
        let item = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "竿の長さが入る幅があるか")).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5))
        item.tap()
        XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5), "押したらチェックが付いて 3 になる")
        item.tap()
        XCTAssertTrue(app.staticTexts["2"].waitForExistence(timeout: 5), "もう一度押すと外れて 2 に戻る")

        // メモ欄に書いて、外を押すとキーボードが下がる。
        // 外側の画面（466x678）では欄が下の端にかかるので、見える所まで送ってから押す
        let note = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        app.scrollViews.firstMatch.swipeUp()
        note.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "メモ欄を押すとキーボードが出る")
        app.typeText("。金物は大工さん")
        app.staticTexts["メモ"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.descendants(matching: .any).containing(NSPredicate(format: "value CONTAINS %@", "金物は大工さん")).firstMatch.exists, "書いたメモが残る")
    }
}

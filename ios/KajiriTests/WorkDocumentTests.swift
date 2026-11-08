import Testing
@testable import Kajiri

@Suite("カジリが作ったチェックリストを読み分ける")
struct WorkDocumentTests {
    let sample = """
    【使い方】
    ・見たら □ を ■ に変える
    ・答えはメモ欄に書く
    【1 物干し竿】
    見る場所
    □ 物干し金物をつける位置
    ■ 竿の長さが入る幅があるか
    メモ：南側
    【2 住所変更】
    ☐ 表札・ポストをつける位置
    """

    @Test("□ と ☐ はチェックしていない項目、■ はチェックした項目になる")
    func checks() {
        let document = WorkDocument.parse(sample)
        let checks = document.blocks.compactMap { block -> (String, Bool)? in
            if case let .check(_, text, initially) = block { return (text, initially) }
            return nil
        }
        #expect(checks.map(\.0) == ["物干し金物をつける位置", "竿の長さが入る幅があるか", "表札・ポストをつける位置"])
        #expect(checks.map(\.1) == [false, true, false])
        #expect(document.hasChecklist)
    }

    @Test("【使い方】の段は出さない（アプリでチェックできるので要らない）")
    func dropsUsage() {
        let document = WorkDocument.parse(sample)
        #expect(!document.blocks.contains(.heading("使い方")))
        #expect(!document.blocks.contains(.text("・見たら □ を ■ に変える")))
        #expect(document.blocks.first == .heading("1 物干し竿"))
    }

    @Test("「メモ：」は書きこめる欄になり、書いてあった文を最初に入れる")
    func notes() {
        let document = WorkDocument.parse(sample)
        let notes = document.blocks.compactMap { block -> String? in
            if case let .note(_, label, initial) = block { return "\(label)=\(initial)" }
            return nil
        }
        #expect(notes == ["メモ=南側"])
    }

    @Test("チェックリストの無い下書きは、そのまま文として扱う")
    func plainText() {
        let document = WorkDocument.parse("【返信の下書き】\nいつもお世話になっております。\n（ここに一言）")
        #expect(!document.hasChecklist)
    }

    @Test("押した項目は反対になり、送る文には ■ とメモが入る")
    func export() {
        let document = WorkDocument.parse(sample)
        var progress = WorkProgress.empty
        let first = document.checkIDs[0]
        let second = document.checkIDs[1]
        progress.toggle(first)
        progress.toggle(second)
        let noteID = document.blocks.compactMap { block -> String? in
            if case let .note(id, _, _) = block { return id }
            return nil
        }[0]
        progress.notes[noteID] = "北側に変更"
        #expect(progress.checkedCount(in: document) == 1)
        let text = document.exportText(progress: progress)
        #expect(text.contains("■ 物干し金物をつける位置"))
        #expect(text.contains("□ 竿の長さが入る幅があるか"))
        #expect(text.contains("メモ：北側に変更"))
        #expect(!text.contains("使い方"))
    }

    @Test("保存した進み具合を読み戻せる。壊れた値は空に戻す")
    func codec() {
        var progress = WorkProgress.empty
        progress.toggle("3")
        progress.notes["7"] = "メモ"
        #expect(WorkProgress.decode(progress.encoded()) == progress)
        #expect(WorkProgress.decode("壊れた値") == .empty)
        #expect(WorkProgress.decode(nil) == .empty)
    }
}

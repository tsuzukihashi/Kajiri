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

    /// 前の版のカジリが作っていた、説明が長い手続きの並び
    let longList = """
    引っ越し日：（ここに日付）
    今の住所と新しい住所は同じ市区町村か：（はい／いいえ）

    【引っ越し前にやる】
    ・郵便の転居届
    郵便局の窓口かネットで出す。旧住所あての郵便が1年間新住所に届く（要確認）
    1週間前までに出すと安心（要確認）
    ・インターネット回線
    早めに申し込む（要確認）
    """

    private func checks(_ document: WorkDocument) -> [(String, Bool, [String])] {
        document.blocks.compactMap { block -> (String, Bool, [String])? in
            if case let .check(_, text, initially, details) = block { return (text, initially, details) }
            return nil
        }
    }

    @Test("□ と ☐ はチェックしていない項目、■ はチェックした項目になる")
    func checksAreRead() {
        let document = WorkDocument.parse(sample)
        let found = checks(document)
        #expect(found.map(\.0) == ["物干し金物をつける位置", "竿の長さが入る幅があるか", "表札・ポストをつける位置"])
        #expect(found.map(\.1) == [false, true, false])
        #expect(document.hasChecklist)
        #expect(document.isStructured)
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
            if case let .note(_, label, initial, _) = block { return "\(label)=\(initial)" }
            return nil
        }
        #expect(notes == ["メモ=南側"])
    }

    @Test("□ のすぐ下の行は、その項目の説明になる。空行や見出しで切れる")
    func detailsBelongToTheItem() {
        let document = WorkDocument.parse("【前】\n□ 転出届を出す\n引っ越しの前後14日以内\n今の役所\n\nあとで読む文\n【後】\n□ 転入届を出す")
        let found = checks(document)
        #expect(found[0].2 == ["引っ越しの前後14日以内", "今の役所"])
        #expect(found[1].2 == [])
        #expect(document.blocks.contains(.text("あとで読む文")))
    }

    @Test("「聞くこと」のような小見出しは、上の項目の説明にしない。「1か月前まで」は説明になる")
    func subheadingsAreNotDetails() {
        let document = WorkDocument.parse("【1 物干し竿】\n見る場所\n□ 竿の長さが入る幅があるか\n聞くこと\n□ 金物はいつ、誰がつけるか\n【前】\n□ ネット回線の移転を申し込む\n1か月前まで\n□ 郵便局に転居届を出す")
        let found = checks(document)
        #expect(found.map(\.2) == [[], [], ["1か月前まで"], []])
        #expect(document.blocks.contains(.text("聞くこと")))
        #expect(document.blocks.contains(.text("見る場所")))
    }

    @Test("行ごとの「（要確認）」は外し、最後に1行だけ注意を出す")
    func hedgesAreGathered() {
        let document = WorkDocument.parse(longList)
        let bullets = document.blocks.compactMap { block -> (String, [String])? in
            if case let .bullet(text, details) = block { return (text, details) }
            return nil
        }
        #expect(bullets.map(\.0) == ["郵便の転居届", "インターネット回線"])
        #expect(bullets[0].1 == ["郵便局の窓口かネットで出す。旧住所あての郵便が1年間新住所に届く", "1週間前までに出すと安心"])
        #expect(!document.blocks.description.contains("要確認"))
        #expect(document.hadHedges)
        #expect(document.footnotes.count == 1)
        #expect(document.isStructured)
        #expect(!document.hasChecklist)
    }

    @Test("カジリが書いた「※ 」の行があれば、それを注意として出す")
    func writtenFootnote() {
        let document = WorkDocument.parse("【前】\n□ 転出届を出す\n※ 日数は目安。出す前に各窓口の案内で確かめる")
        #expect(document.footnotes == ["日数は目安。出す前に各窓口の案内で確かめる"])
        #expect(checks(document)[0].2 == [])
    }

    @Test("紙で書きこむ空欄は、書く欄と選ぶ欄になる")
    func blankFields() {
        let document = WorkDocument.parse(longList)
        #expect(document.blocks.first == .note(id: "0", label: "引っ越し日", initial: "", hint: "日付"))
        #expect(document.blocks.dropFirst().first == .choice(id: "1", label: "今の住所と新しい住所は同じ市区町村か", options: ["はい", "いいえ"]))
    }

    @Test("条件のかっこ書きは、空欄にしない")
    func conditionIsNotAField() {
        let document = WorkDocument.parse("転入届：（市区町村が変わるとき）")
        #expect(document.blocks == [.text("転入届：（市区町村が変わるとき）")])
    }

    @Test("メールの下書きのような地の文は、分けずに文のまま見せる")
    func plainText() {
        let document = WorkDocument.parse("【返信の下書き】\nいつもお世話になっております。\n・日時：11月20日\n・場所：本社\n\nよろしくお願いいたします。\n（ここに一言）")
        #expect(!document.hasChecklist)
        #expect(!document.isStructured)
    }

    @Test("押した項目は反対になり、送る文には ■ とメモと選んだものが入る")
    func export() {
        let document = WorkDocument.parse(sample)
        var progress = WorkProgress.empty
        let first = document.checkIDs[0]
        let second = document.checkIDs[1]
        progress.toggle(first)
        progress.toggle(second)
        let noteID = document.blocks.compactMap { block -> String? in
            if case let .note(id, _, _, _) = block { return id }
            return nil
        }[0]
        progress.notes[noteID] = "北側に変更"
        #expect(progress.checkedCount(in: document) == 1)
        let text = document.exportText(progress: progress)
        #expect(text.contains("■ 物干し金物をつける位置"))
        #expect(text.contains("□ 竿の長さが入る幅があるか"))
        #expect(text.contains("メモ：北側に変更"))
        #expect(!text.contains("使い方"))

        let list = WorkDocument.parse(longList)
        var picked = WorkProgress.empty
        picked.notes["1"] = "いいえ"
        let listText = list.exportText(progress: picked)
        #expect(listText.contains("今の住所と新しい住所は同じ市区町村か：いいえ"))
        #expect(listText.contains("※ 期限や日数は目安です。"))
        #expect(!listText.contains("要確認"))
    }

    @Test("「次はこれ」は、まだチェックしていない最初の項目")
    func nextItem() {
        let document = WorkDocument.parse(sample)
        var progress = WorkProgress.empty
        #expect(progress.nextCheckID(in: document) == document.checkIDs[0])
        progress.toggle(document.checkIDs[0])
        // 2つ目は届いたときからチェック済みなので、3つ目
        #expect(progress.nextCheckID(in: document) == document.checkIDs[2])
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

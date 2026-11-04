import Testing
@testable import Kajiri

struct PlainTextTests {
    @Test("見出し・表・太字・横線を、iPhone で読める素の文にする")
    func cleansMarkdown() {
        let input = """
        ## ① 会社から来る書類
        | 書類 | 誰が出す |
        |---|---|
        | 扶養控除等申告書 | **全員** |
        ---
        - 源泉徴収票
        """
        #expect(PlainText.clean(input) == """
        【① 会社から来る書類】
        ・書類 / 誰が出す
        ・扶養控除等申告書 / 全員
        ・源泉徴収票
        """)
    }

    @Test("素の文はそのまま")
    func keepsPlainText() {
        let input = "お問い合わせありがとうございます。\n\n（ここに一言）"
        #expect(PlainText.clean(input) == input)
    }
}

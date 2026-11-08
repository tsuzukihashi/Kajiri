import Foundation

/// カジリが作ったもの（下書き・調べもの・一覧）を、画面で扱える形に読み分けたもの。
/// 「□ 」で始まる行はチェックできる項目、「・」は並べた項目、その下に続く行は項目のくわしい説明、
/// 「メモ：」の行は書きこめる欄、【】は見出し、「※ 」は確かめきれなかったことのまとめ。
///
/// ADHD の人は長い文の中から要点を拾うのが苦手なので（docs/research-readable-output.md）、
/// 行ごとの「（要確認）」は外して最後の1行にまとめ、説明の行は項目の下にたたむ。
/// 「□ を ■ に変える」のような、紙で使うための説明（【使い方】の段）は、アプリでチェックできるので出さない
nonisolated struct WorkDocument: Equatable, Sendable {
    enum Block: Equatable, Sendable {
        case heading(String)
        case text(String)
        /// 「・」で始まる項目（チェックはしない）。details はすぐ下に続く説明の行
        case bullet(text: String, details: [String])
        /// id は元の文章の行番号（文章は届いたあと変わらないので、チェックの保存の鍵に使える）
        case check(id: String, text: String, initiallyChecked: Bool, details: [String])
        /// 書きこむ欄。label は「メモ」など、initial は最初から書いてあった文、hint は空のときに見せる言葉
        case note(id: String, label: String, initial: String, hint: String?)
        /// 「同じ市区町村か：(はい／いいえ)」のような、選ぶだけの欄
        case choice(id: String, label: String, options: [String])
        /// 「※ 」で始まる、確かめきれなかったことのまとめ
        case footnote(String)
    }

    let blocks: [Block]
    /// 行ごとに付いていた「（要確認）」を外したか（外したら、最後に1行だけ注意を出す）
    let hadHedges: Bool

    /// チェックできる項目があるか
    var hasChecklist: Bool { checkIDs.isEmpty == false }

    /// 見出しや項目に分けて見せるか。メールの下書きのような地の文だけのものは、今までどおり文のまま見せる
    var isStructured: Bool {
        if hasChecklist { return true }
        var headings = 0
        for block in blocks {
            switch block {
            case .heading: headings += 1
            case let .bullet(_, details) where details.isEmpty == false: return true
            case .note, .choice: return true
            default: break
            }
        }
        return headings >= 2
    }

    var checkIDs: [String] {
        blocks.compactMap { if case let .check(id, _, _, _) = $0 { return id } else { return nil } }
    }

    /// 最後に出す注意。カジリが書いた「※ 」の行があればそれ、無くて「要確認」を外したなら決まった1行
    var footnotes: [String] {
        let written = blocks.compactMap { if case let .footnote(text) = $0 { return text } else { return nil } }
        if written.isEmpty == false { return written }
        return hadHedges ? [String(localized: "期限や日数は目安です。出す前に、それぞれの窓口の案内で確かめておくと安心です。")] : []
    }

    private static let uncheckedMarks = ["□", "☐", "◻", "- [ ]", "[ ]", "・[ ]"]
    private static let checkedMarks = ["■", "☑", "✅", "☒", "- [x]", "[x]", "- [X]", "[X]"]
    private static let bulletMarks = ["・", "•", "●", "○"]
    private static let noteLabels = ["メモ", "メモ欄", "答え", "記入欄"]

    static func parse(_ body: String) -> WorkDocument {
        var blocks: [Block] = []
        var skippingUsage = false
        var hadHedges = false
        /// すぐ上の項目（説明の行をぶら下げる先）。空行・見出し・欄が来たら切る
        var lastItem: Int?

        func cleaned(_ text: String) -> String {
            let (result, removed) = stripHedges(text)
            if removed { hadHedges = true }
            return result
        }

        let allLines = body.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        for (index, line) in allLines.enumerated() {
            guard line.isEmpty == false else {
                lastItem = nil
                continue
            }
            if line.hasPrefix("【"), line.hasSuffix("】") {
                let title = String(line.dropFirst().dropLast())
                // 紙で使うための説明はアプリでは要らない
                skippingUsage = title.contains("使い方")
                if !skippingUsage { blocks.append(.heading(cleaned(title))) }
                lastItem = nil
                continue
            }
            if skippingUsage { continue }
            if let rest = strip(line, marks: uncheckedMarks) {
                blocks.append(.check(id: "\(index)", text: cleaned(rest), initiallyChecked: false, details: []))
                lastItem = blocks.count - 1
            } else if let rest = strip(line, marks: checkedMarks) {
                blocks.append(.check(id: "\(index)", text: cleaned(rest), initiallyChecked: true, details: []))
                lastItem = blocks.count - 1
            } else if let (label, value) = note(line) {
                blocks.append(.note(id: "\(index)", label: label, initial: value, hint: nil))
                lastItem = nil
            } else if let field = blankField(line) {
                switch field {
                case let .choice(label, options):
                    blocks.append(.choice(id: "\(index)", label: label, options: options))
                case let .note(label, hint):
                    blocks.append(.note(id: "\(index)", label: label, initial: "", hint: hint))
                }
                lastItem = nil
            } else if let rest = strip(line, marks: ["※"]) {
                let text = cleaned(rest)
                if text.isEmpty == false { blocks.append(.footnote(text)) }
                lastItem = nil
            } else if let rest = strip(line, marks: bulletMarks) {
                blocks.append(.bullet(text: cleaned(rest), details: []))
                lastItem = blocks.count - 1
            } else if let item = lastItem, !isSubheading(line, next: allLines[(index + 1)...].first { $0.isEmpty == false }) {
                let detail = cleaned(line)
                guard detail.isEmpty == false else { continue }
                blocks[item] = appending(detail, to: blocks[item])
            } else {
                let text = cleaned(line)
                if text.isEmpty == false { blocks.append(.text(text)) }
                lastItem = nil
            }
        }
        return WorkDocument(blocks: blocks, hadHedges: hadHedges)
    }

    /// 送る・コピーするときの文。チェックした項目は ■、書いたメモ・選んだものはその欄に入れる
    func exportText(progress: WorkProgress) -> String {
        var lines: [String] = []
        for block in blocks {
            switch block {
            case let .heading(title):
                if !lines.isEmpty { lines.append("") }
                lines.append("【\(title)】")
            case let .text(text):
                lines.append(text)
            case let .bullet(text, details):
                lines.append("・\(text)")
                lines.append(contentsOf: details.map { "　\($0)" })
            case let .check(id, text, initiallyChecked, details):
                lines.append("\(progress.isChecked(id, initially: initiallyChecked) ? "■" : "□") \(text)")
                lines.append(contentsOf: details.map { "　\($0)" })
            case let .note(id, label, initial, _):
                lines.append("\(label)：\(progress.notes[id] ?? initial)")
            case let .choice(id, label, options):
                let picked = progress.notes[id] ?? ""
                lines.append("\(label)：\(picked.isEmpty ? options.joined(separator: "／") : picked)")
            case .footnote:
                break
            }
        }
        let notes = footnotes
        if notes.isEmpty == false {
            lines.append("")
            lines.append(contentsOf: notes.map { "※ \($0)" })
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - 読み分け

    private static func appending(_ detail: String, to block: Block) -> Block {
        switch block {
        case let .bullet(text, details):
            .bullet(text: text, details: details + [detail])
        case let .check(id, text, initiallyChecked, details):
            .check(id: id, text: text, initiallyChecked: initiallyChecked, details: details + [detail])
        default:
            block
        }
    }

    /// 「見る場所」「聞くこと」のような、段の中の小見出しか（すぐ上の項目の説明ではない）。
    /// 「1か月前まで」のような短い説明と分けるため、数字や句読点の無い短い名詞で、次の行が項目のものだけにする
    private static func isSubheading(_ line: String, next: String?) -> Bool {
        guard let next, line.count <= 10 else { return false }
        let nextIsItem = strip(next, marks: uncheckedMarks + checkedMarks + bulletMarks) != nil
        guard nextIsItem, line.contains(where: { $0.isNumber || "。、，,（）()".contains($0) }) == false else { return false }
        if line.hasSuffix("：") || line.hasSuffix(":") { return true }
        return ["こと", "場所", "ところ", "もの", "物", "手順", "人", "先"].contains { line.hasSuffix($0) }
    }

    /// 「（要確認）」「(要確認)」「【要確認】」と、行末の「要確認」を外す
    static func stripHedges(_ text: String) -> (String, Bool) {
        var result = text
        let patterns = [
            #"[（(【\[]\s*要確認[^）)】\]]*[）)】\]]"#,
            #"[、。\s]*要確認[。]?$"#,
        ]
        for pattern in patterns {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        result = result.trimmingCharacters(in: .whitespaces)
        return (result, result != text.trimmingCharacters(in: .whitespaces))
    }

    private static func strip(_ line: String, marks: [String]) -> String? {
        for mark in marks where line.hasPrefix(mark) {
            return String(line.dropFirst(mark.count)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func note(_ line: String) -> (String, String)? {
        for label in noteLabels {
            for colon in ["：", ":"] where line.hasPrefix(label + colon) {
                let value = String(line.dropFirst(label.count + colon.count)).trimmingCharacters(in: .whitespaces)
                return (label, value)
            }
        }
        return nil
    }

    private enum BlankField {
        case choice(label: String, options: [String])
        case note(label: String, hint: String)
    }

    /// 「引っ越し日：(ここに日付)」「同じ市区町村か：(はい／いいえ)」のような、紙で書きこむための空欄
    private static func blankField(_ line: String) -> BlankField? {
        guard let match = line.firstMatch(of: #/^(.{1,30}?)[：:]\s*[（(](.+)[）)]$/#) else { return nil }
        let label = String(match.1).trimmingCharacters(in: .whitespaces)
        let inner = String(match.2).trimmingCharacters(in: .whitespaces)
        if inner.hasPrefix("ここに") {
            let hint = String(inner.dropFirst("ここに".count)).trimmingCharacters(in: .whitespaces)
            return .note(label: label, hint: hint)
        }
        let options = inner.split(whereSeparator: { "／/・|｜".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
        if (2...4).contains(options.count), options.allSatisfy({ $0.count <= 8 }) {
            return .choice(label: label, options: options)
        }
        return nil
    }
}

/// チェックした項目と、書いたメモ・選んだもの。Step.workProgressJSON に保存する
nonisolated struct WorkProgress: Codable, Equatable, Sendable {
    /// 押して状態を変えた項目（届いたときの状態から、反対にしたもの）
    var toggled: Set<String>
    /// 書いたメモと、選んだもの（欄の id ごと）
    var notes: [String: String]

    static let empty = WorkProgress(toggled: [], notes: [:])

    func isChecked(_ id: String, initially: Bool) -> Bool {
        toggled.contains(id) ? !initially : initially
    }

    mutating func toggle(_ id: String) {
        if toggled.contains(id) { toggled.remove(id) } else { toggled.insert(id) }
    }

    func checkedCount(in document: WorkDocument) -> Int {
        document.blocks.reduce(0) { count, block in
            if case let .check(id, _, initially, _) = block, isChecked(id, initially: initially) { return count + 1 }
            return count
        }
    }

    /// まだチェックしていない最初の項目（「次はこれ」）
    func nextCheckID(in document: WorkDocument) -> String? {
        for block in document.blocks {
            if case let .check(id, _, initially, _) = block, !isChecked(id, initially: initially) { return id }
        }
        return nil
    }

    static func decode(_ json: String?) -> WorkProgress {
        guard let json, let data = json.data(using: .utf8),
              let progress = try? JSONDecoder().decode(WorkProgress.self, from: data) else { return .empty }
        return progress
    }

    func encoded() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

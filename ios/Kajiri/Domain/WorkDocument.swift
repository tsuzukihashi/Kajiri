import Foundation

/// カジリが作ったもの（下書き・調べもの・一覧）を、画面で扱える形に読み分けたもの。
/// 「□ 」で始まる行はチェックできる項目、「メモ：」の行は書きこめる欄、【】は見出し。
/// 「□ を ■ に変える」のような、紙で使うための説明（【使い方】の段）は、アプリでチェックできるので出さない
nonisolated struct WorkDocument: Equatable, Sendable {
    enum Block: Equatable, Sendable {
        case heading(String)
        case text(String)
        /// id は元の文章の行番号（文章は届いたあと変わらないので、チェックの保存の鍵に使える）
        case check(id: String, text: String, initiallyChecked: Bool)
        /// 「メモ：」の欄。label は「メモ」など、initial は最初から書いてあった文
        case note(id: String, label: String, initial: String)
    }

    let blocks: [Block]

    /// チェックできる項目があるか（無ければ、今までどおり文章のまま見せる）
    var hasChecklist: Bool { checkIDs.isEmpty == false }

    var checkIDs: [String] {
        blocks.compactMap { if case let .check(id, _, _) = $0 { return id } else { return nil } }
    }

    private static let uncheckedMarks = ["□", "☐", "◻", "- [ ]", "[ ]", "・[ ]"]
    private static let checkedMarks = ["■", "☑", "✅", "☒", "- [x]", "[x]", "- [X]", "[X]"]
    private static let noteLabels = ["メモ", "メモ欄", "答え", "記入欄"]

    static func parse(_ body: String) -> WorkDocument {
        var blocks: [Block] = []
        var skippingUsage = false
        for (index, raw) in body.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard line.isEmpty == false else { continue }
            if line.hasPrefix("【"), line.hasSuffix("】") {
                let title = String(line.dropFirst().dropLast())
                // 紙で使うための説明はアプリでは要らない
                skippingUsage = title.contains("使い方")
                if !skippingUsage { blocks.append(.heading(title)) }
                continue
            }
            if skippingUsage { continue }
            if let rest = strip(line, marks: uncheckedMarks) {
                blocks.append(.check(id: "\(index)", text: rest, initiallyChecked: false))
            } else if let rest = strip(line, marks: checkedMarks) {
                blocks.append(.check(id: "\(index)", text: rest, initiallyChecked: true))
            } else if let (label, value) = note(line) {
                blocks.append(.note(id: "\(index)", label: label, initial: value))
            } else {
                blocks.append(.text(line))
            }
        }
        return WorkDocument(blocks: blocks)
    }

    /// 送る・コピーするときの文。チェックした項目は ■、書いたメモはその欄に入れる
    func exportText(progress: WorkProgress) -> String {
        var lines: [String] = []
        for block in blocks {
            switch block {
            case let .heading(title):
                if !lines.isEmpty { lines.append("") }
                lines.append("【\(title)】")
            case let .text(text):
                lines.append(text)
            case let .check(id, text, initiallyChecked):
                lines.append("\(progress.isChecked(id, initially: initiallyChecked) ? "■" : "□") \(text)")
            case let .note(id, label, initial):
                lines.append("\(label)：\(progress.notes[id] ?? initial)")
            }
        }
        return lines.joined(separator: "\n")
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
}

/// チェックした項目と、書いたメモ。Step.workProgressJSON に保存する
nonisolated struct WorkProgress: Codable, Equatable, Sendable {
    /// 押して状態を変えた項目（届いたときの状態から、反対にしたもの）
    var toggled: Set<String>
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
            if case let .check(id, _, initially) = block, isChecked(id, initially: initially) { return count + 1 }
            return count
        }
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

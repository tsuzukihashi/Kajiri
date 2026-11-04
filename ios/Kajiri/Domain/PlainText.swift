import Foundation

/// カジリが作った文を、iPhone で読みやすい素の文にする。
/// 中継サーバには「Markdown を使わない」と頼んでいるが、混ざって返ってきたときに記号を見せないための保険。
enum PlainText {
    static func clean(_ text: String) -> String {
        var lines: [String] = []
        for raw in text.components(separatedBy: "\n") {
            var line = raw.trimmingCharacters(in: .whitespaces)
            // 表の区切り行（|---|---|）と横線（---）は捨てる
            if line.range(of: #"^\|?\s*:?-{3,}"#, options: .regularExpression) != nil { continue }
            // 見出し（## ①…）は【】で囲む
            if let range = line.range(of: #"^#{1,6}\s+"#, options: .regularExpression) {
                line = "【" + line[range.upperBound...].trimmingCharacters(in: .whitespaces) + "】"
            }
            // 表の行（| a | b |）は「・a / b」にする
            if line.hasPrefix("|") && line.hasSuffix("|") {
                let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                line = "・" + cells.joined(separator: " / ")
            }
            // 箇条書きの - / * は「・」に
            if let range = line.range(of: #"^[-*]\s+"#, options: .regularExpression) {
                line = "・" + line[range.upperBound...]
            }
            line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
            lines.append(line)
        }
        // 空行が3つ以上続かないように
        var result: [String] = []
        for line in lines {
            if line.isEmpty && result.last?.isEmpty == true { continue }
            result.append(line)
        }
        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

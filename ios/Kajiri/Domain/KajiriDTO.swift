import Foundation

/// 中継サーバが返す形。functions/src/prompts.ts の DECOMPOSE_SCHEMA / RESPLIT_SCHEMA と同じ（snake_case）。
struct StepDTO: Codable, Sendable, Equatable {
    var title: String
    var minutes: Int
    var owner: String
    var quadrant: String
    var firstMotion: String
    var due: String?
    var kajiriWork: String?
    var askWho: String?
    var needsComputer: Bool

    enum CodingKeys: String, CodingKey {
        case title, minutes, owner, quadrant, due
        case firstMotion = "first_motion"
        case kajiriWork = "kajiri_work"
        case askWho = "ask_who"
        case needsComputer = "needs_computer"
    }
}

struct DecomposeResult: Codable, Sendable, Equatable {
    var logTitle: String
    var deadline: String?
    var deadlineNote: String
    var why: String
    var steps: [StepDTO]
    var comment: String

    enum CodingKeys: String, CodingKey {
        case deadline, why, steps, comment
        case logTitle = "log_title"
        case deadlineNote = "deadline_note"
    }
}

struct ResplitResult: Codable, Sendable, Equatable {
    var steps: [StepDTO]
    var comment: String
}

struct WorkResult: Codable, Sendable, Equatable {
    var title: String
    var body: String
}

#if DEBUG
extension StepDTO {
    static func sample(_ title: String, minutes: Int, owner: StepOwner, quadrant: Quadrant, work: String?) -> StepDTO {
        StepDTO(
            title: title, minutes: minutes, owner: owner.rawValue, quadrant: quadrant.rawValue,
            firstMotion: "手を伸ばす", due: nil, kajiriWork: work, askWho: owner == .other ? "会社の総務" : nil,
            needsComputer: false
        )
    }
}

extension DecomposeResult {
    static let sampleTax = DecomposeResult(
        logTitle: "確定申告",
        deadline: "2027-03-15",
        deadlineNote: "確定申告の一般的な期限",
        why: "春を、気持ちよく迎えられる",
        steps: [
            .sample("分からないことを3つ書き出す", minutes: 5, owner: .me, quadrant: .stock, work: nil),
            .sample("使う書類の一覧を作る", minutes: 3, owner: .kajiri, quadrant: .handoff, work: "確定申告で使う書類の一覧"),
            .sample("会社に源泉徴収票を頼む", minutes: 3, owner: .other, quadrant: .handoff, work: nil),
            .sample("源泉徴収票が届く", minutes: 1, owner: .wait, quadrant: .stock, work: nil),
            .sample("マイナンバーカードを机に出す", minutes: 1, owner: .me, quadrant: .today, work: nil),
        ],
        comment: "7本の薪にした。まずはここからな。"
    )
}
#endif

import Foundation
import SwiftData

/// 丸太: 投げられた大きなタスク。カジリが薪（Step）に分ける。
@Model
final class Log {
    var uuid: UUID
    var title: String
    /// 最初に投げられたメモ（カジリが下書きを作るときにも読む）
    var memo: String
    var deadline: Date?
    var deadlineNote: String
    /// 終わると何がうれしいか（止まったときに見せる）
    var why: String
    var kajiriComment: String
    var createdAt: Date
    /// カレンダーの予定から投げた丸太なら、その予定（CalendarEvent.id）
    var sourceEventID: String?
    /// 締め切りを iPhone のカレンダーに入れたなら、その予定（EKEvent.eventIdentifier）
    var deadlineEventID: String?

    @Relationship(deleteRule: .cascade, inverse: \Step.log)
    var steps: [Step]

    init(title: String, memo: String, deadline: Date?, deadlineNote: String, why: String, kajiriComment: String, createdAt: Date, sourceEventID: String?) {
        self.uuid = UUID()
        self.title = title
        self.memo = memo
        self.deadline = deadline
        self.deadlineNote = deadlineNote
        self.why = why
        self.kajiriComment = kajiriComment
        self.createdAt = createdAt
        self.sourceEventID = sourceEventID
        self.deadlineEventID = nil
        self.steps = []
    }

    var sortedSteps: [Step] { steps.sorted { $0.order < $1.order } }
    var doneCount: Int { steps.filter(\.isDone).count }
    var isFinished: Bool { !steps.isEmpty && steps.allSatisfy { $0.isDone || $0.quadrant == .drop } }

    /// いま誰の番か（まだ終わっていない最初の薪）
    var nextStep: Step? { sortedSteps.first { !$0.isDone && $0.quadrant != .drop } }
}

/// 薪: すぐ手が動く大きさの一歩
@Model
final class Step {
    var uuid: UUID
    var order: Int
    var title: String
    var minutes: Int
    var ownerRaw: String
    var quadrantRaw: String
    var firstMotion: String
    var due: Date?
    /// カジリが作るもの（owner = kajiri のとき）
    var kajiriWork: String?
    /// 誰に頼むか（owner = other のとき）
    var askWho: String?
    var needsComputer: Bool

    var isDone: Bool
    var doneAt: Date?
    var postponeCount: Int
    /// この日より前は「今日の薪」に出さない（「いまじゃない」を押したとき）
    var notBefore: Date?
    /// 「この1本だけ」を開いた時刻と、かかった分（見積もりと比べる）
    var startedAt: Date?
    var actualMinutes: Int?

    /// カジリの番の薪の進み具合と、できあがったもの
    var workStateRaw: String
    var workTitle: String?
    var workBody: String?

    var log: Log?

    init(order: Int, dto: StepDTO) {
        self.uuid = UUID()
        self.order = order
        self.title = dto.title
        self.minutes = max(1, dto.minutes)
        self.ownerRaw = dto.owner
        self.quadrantRaw = dto.quadrant
        self.firstMotion = dto.firstMotion
        self.due = JapanDate.date(day: dto.due)
        self.kajiriWork = dto.kajiriWork
        self.askWho = dto.askWho
        self.needsComputer = dto.needsComputer
        self.isDone = false
        self.doneAt = nil
        self.postponeCount = 0
        self.notBefore = nil
        self.startedAt = nil
        self.actualMinutes = nil
        self.workStateRaw = WorkState.idle.rawValue
        self.workTitle = nil
        self.workBody = nil
    }

    var owner: StepOwner {
        get { StepOwner(rawValue: ownerRaw) ?? .me }
        set { ownerRaw = newValue.rawValue }
    }

    var quadrant: Quadrant {
        get { Quadrant(rawValue: quadrantRaw) ?? .stock }
        set { quadrantRaw = newValue.rawValue }
    }

    var workState: WorkState {
        get { WorkState(rawValue: workStateRaw) ?? .idle }
        set { workStateRaw = newValue.rawValue }
    }
}

/// 誰がやるか
enum StepOwner: String, CaseIterable, Sendable {
    case me = "self"
    case kajiri
    case other
    case wait

    var label: String {
        switch self {
        case .me: String(localized: "じぶん")
        case .kajiri: String(localized: "カジリ")
        case .other: String(localized: "頼む")
        case .wait: String(localized: "待ち")
        }
    }
}

/// タスク管理の4象限（急ぐか × 大事か）
enum Quadrant: String, CaseIterable, Sendable {
    case today
    case stock
    case handoff
    case drop

    var label: String {
        switch self {
        case .today: String(localized: "今日やる")
        case .stock: String(localized: "あとでやる")
        case .handoff: String(localized: "任せる")
        case .drop: String(localized: "やらない")
        }
    }

    var note: String {
        switch self {
        case .today: String(localized: "急ぐし、大事")
        case .stock: String(localized: "空き時間に、カジリが置く")
        case .handoff: String(localized: "カジリか、だれかがやる")
        case .drop: String(localized: "やらなくていい。消さずに残しておく")
        }
    }
}

/// カジリの番の薪の進み具合
enum WorkState: String, Sendable {
    case idle
    case working
    case ready
    case failed
}

import Foundation
import Observation
import SwiftData

/// 丸太と薪の出し入れと、カジリへのお願いをまとめる。
/// SwiftData の ModelContext は MainActor でしか触れないので、ここも MainActor に置く（重い仕事は中継サーバ側）。
@MainActor
@Observable
final class LogUseCase {
    private let context: ModelContext
    private let api: any KajiriAPIProtocol

    init(context: ModelContext, api: any KajiriAPIProtocol) {
        self.context = context
        self.api = api
    }

    // MARK: 投げる → かじる

    func decompose(memo: String, now: Date) async throws -> DecomposeResult {
        try await api.decompose(memo: memo, today: now, overrun: TodayPicker.overrun(of: allSteps()))
    }

    /// 分けた結果を丸太として保存し、カジリの番の薪を裏で同時に進める
    @discardableResult
    func save(_ result: DecomposeResult, memo: String, sourceEventID: String?, now: Date) -> Log {
        let log = Log(
            title: result.logTitle,
            memo: memo,
            deadline: JapanDate.date(day: result.deadline),
            deadlineNote: result.deadlineNote,
            why: result.why,
            kajiriComment: result.comment,
            createdAt: now,
            sourceEventID: sourceEventID
        )
        context.insert(log)
        for (index, dto) in result.steps.enumerated() {
            let step = Step(order: index * 10, dto: dto)
            context.insert(step)
            step.log = log
        }
        try? context.save()
        startKajiriWork(in: log, now: now)
        return log
    }

    // MARK: 1本ずつ片づける

    func start(_ step: Step, now: Date) {
        if step.startedAt == nil { step.startedAt = now }
        try? context.save()
    }

    func complete(_ step: Step, now: Date) {
        step.isDone = true
        step.doneAt = now
        if let started = step.startedAt {
            // 開きっぱなしで放っておいた分は数えない（2時間まで）
            step.actualMinutes = min(120, max(1, Int(now.timeIntervalSince(started) / 60)))
        }
        try? context.save()
    }

    func undo(_ step: Step) {
        step.isDone = false
        step.doneAt = nil
        try? context.save()
    }

    /// いまじゃない: 明日まで今日の薪に出さない
    func postpone(_ step: Step, now: Date) {
        step.postponeCount += 1
        step.notBefore = JapanDate.addingDays(1, to: now)
        step.startedAt = nil
        try? context.save()
    }

    /// 気が乗らない: 川に流す（消さずに下流に残す）
    func drop(_ step: Step) {
        step.quadrant = .drop
        try? context.save()
    }

    /// 気が乗らない: 仲間に頼む側へ回す
    func handOff(_ step: Step) {
        step.owner = .other
        step.quadrant = .handoff
        try? context.save()
    }

    // MARK: 割り直す

    func resplit(_ step: Step, now: Date) async throws -> ResplitResult {
        try await api.resplit(logTitle: step.log?.title ?? step.title, step: step.title, postponed: step.postponeCount + 1, today: now)
    }

    /// 元の薪を、小さく割った薪に入れかえる（順番は元の位置に差し込む）
    func apply(_ result: ResplitResult, replacing step: Step, now: Date) {
        guard let log = step.log else { return }
        let base = step.order
        let pieces = result.steps.prefix(9)
        for (index, dto) in pieces.enumerated() {
            let piece = Step(order: base + index, dto: dto)
            piece.postponeCount = step.postponeCount + 1
            context.insert(piece)
            piece.log = log
        }
        context.delete(step)
        try? context.save()
        startKajiriWork(in: log, now: now)
    }

    // MARK: カジリの番

    func startKajiriWork(in log: Log, now: Date) {
        let targets = log.steps.filter { $0.owner == .kajiri && $0.workState == .idle && !$0.isDone }
        for step in targets {
            Task { await runWork(step, now: now) }
        }
    }

    func runWork(_ step: Step, now: Date) async {
        guard let log = step.log else { return }
        step.workState = .working
        try? context.save()
        do {
            let result = try await api.work(
                logTitle: log.title,
                step: step.title,
                work: step.kajiriWork ?? step.title,
                memo: log.memo,
                today: now
            )
            step.workTitle = PlainText.clean(result.title)
            step.workBody = PlainText.clean(result.body)
            step.workState = .ready
        } catch {
            step.workBody = error.localizedDescription
            step.workState = .failed
        }
        try? context.save()
    }

    /// 締め切りを iPhone のカレンダーに入れた（同じ締め切りを2回入れないように覚える）
    func markDeadlineInCalendar(_ log: Log, eventIdentifier: String) {
        log.deadlineEventID = eventIdentifier
        try? context.save()
    }

    // MARK: 読む

    func allSteps() -> [Step] {
        (try? context.fetch(FetchDescriptor<Step>())) ?? []
    }

    func step(id: UUID) -> Step? {
        var descriptor = FetchDescriptor<Step>(predicate: #Predicate { $0.uuid == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

#if DEBUG
extension LogUseCase {
    /// Preview 用。メモリの中だけのデータベースと、ネットにつながない偽物の中継サーバ
    static func preview(filled: Bool) -> (LogUseCase, ModelContainer) {
        let container = try! ModelContainer(
            for: Log.self, Step.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let useCase = LogUseCase(context: container.mainContext, api: MockKajiriAPI(delay: .milliseconds(600), fails: false))
        if filled {
            let log = useCase.save(.sampleTax, memo: "確定申告", sourceEventID: nil, now: .now)
            if let first = log.sortedSteps.first {
                first.workState = .ready
            }
            let moving = DecomposeResult(
                logTitle: "引っ越し", deadline: "2026-12-20", deadlineNote: "メモに書いてあった", why: "新しい部屋で最初の週末をゆっくり",
                steps: [
                    .sample("粗大ゴミの受付に電話する", minutes: 10, owner: .me, quadrant: .today, work: nil),
                    .sample("転出届の出し方を調べる", minutes: 5, owner: .kajiri, quadrant: .handoff, work: "転出届の出し方"),
                ],
                comment: "大物から片づけよう。"
            )
            useCase.save(moving, memo: "引っ越し", sourceEventID: "preview-moving", now: .now)
        }
        return (useCase, container)
    }
}
#endif

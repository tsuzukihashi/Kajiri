import SwiftData
import SwiftUI

/// 丸太の中身。薪を「誰の番か」で分けて並べる。じぶんの薪は「この1本だけ」、カジリの薪は受け取る画面へ
struct LogDetailView: View {
    let logID: UUID

    @Environment(CalendarUseCase.self) private var calendar
    @Environment(LogUseCase.self) private var useCase
    @Query private var logs: [Log]
    @State private var deadlineRequest: EventEditorRequest?

    init(logID: UUID) {
        self.logID = logID
        _logs = Query(filter: #Predicate<Log> { $0.uuid == logID })
    }

    var body: some View {
        Group {
            if let log = logs.first {
                content(log)
            } else {
                ContentUnavailableView("この丸太は見つかりませんでした", systemImage: "questionmark", description: Text("消されたのかもしれません。"))
            }
        }
        .background(Theme.ground)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $deadlineRequest) { request in
            EventEditorView(request: request) { savedID in
                if let savedID, let log = logs.first { useCase.markDeadlineInCalendar(log, eventIdentifier: savedID) }
                deadlineRequest = nil
            }
            .ignoresSafeArea()
        }
    }

    private func content(_ log: Log) -> some View {
        let steps = log.sortedSteps
        let mine = steps.filter { !$0.isDone && $0.owner == .me && $0.quadrant != .drop }
        let kajiri = steps.filter { !$0.isDone && $0.owner == .kajiri }
        let others = steps.filter { !$0.isDone && ($0.owner == .other || $0.owner == .wait) && $0.quadrant != .drop }
        let done = steps.filter(\.isDone)
        let dropped = steps.filter { !$0.isDone && $0.quadrant == .drop }
        return ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                LogHeader(log: log)
                deadlineControl(log)
                if !mine.isEmpty {
                    StepSection(title: "じぶんの薪", steps: mine, isLink: true)
                }
                if !kajiri.isEmpty {
                    KajiriInboxCard(steps: kajiri)
                }
                if !others.isEmpty {
                    StepSection(title: "頼む・待ち", steps: others, isLink: false)
                }
                if !done.isEmpty {
                    StepSection(title: "片づいた", steps: done, isLink: false)
                }
                if !dropped.isEmpty {
                    StepSection(title: "やらない（消さずに残しています）", steps: dropped, isLink: true)
                }
                if !log.memo.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("投げたメモ").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
                        Text(log.memo)
                            .font(.system(size: 14))
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card, in: .rect(cornerRadius: 14))
                    }
                }
            }
            .padding(18)
        }
    }

    /// 締め切りを iPhone のカレンダーに入れる（入れたら、入っていることだけ見せる）
    @ViewBuilder
    private func deadlineControl(_ log: Log) -> some View {
        if log.deadline != nil && !log.isFinished {
            if log.deadlineEventID != nil {
                Label("締め切りはカレンダーに入っています", systemImage: "calendar.badge.checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
            } else if calendar.access == .granted {
                Button {
                    deadlineRequest = calendar.deadlineRequest(for: log)
                } label: {
                    Label("締め切りをカレンダーに入れる", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

/// 丸太の名前・締め切り・なぜやるか・進み具合
private struct LogHeader: View {
    let log: Log

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                KajiriImage(pose: log.isFinished ? .dam : .gnaw, size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    if let deadline = log.deadline {
                        Text("\(deadline, format: .dateTime.month().day().weekday())まで")
                            .font(.system(size: 12, weight: .heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.amber, in: .capsule)
                    }
                    Text(log.title).font(.system(size: 24, weight: .black))
                    if !log.kajiriComment.isEmpty {
                        Text(log.kajiriComment).font(.system(size: 13)).foregroundStyle(Theme.sub)
                    }
                }
            }
            ProgressPips(total: log.steps.filter { $0.quadrant != .drop }.count, done: log.doneCount)
            if !log.why.isEmpty {
                Label(log.why, systemImage: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
        }
    }
}

/// 見出しと薪の行の並び
private struct StepSection: View {
    let title: LocalizedStringKey
    let steps: [Step]
    /// 押して「この1本だけ」に行けるか
    let isLink: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
            ForEach(steps) { step in
                if isLink {
                    NavigationLink(value: Route.step(step)) { row(step) }
                        .buttonStyle(.plain)
                } else {
                    row(step)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ step: Step) -> some View {
        if step.owner == .other || step.owner == .wait {
            HStack(spacing: 10) {
                Image(systemName: step.owner == .wait ? "hourglass" : "person.2").frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title).font(.system(size: 15, weight: .bold))
                    if let who = step.askWho, !who.isEmpty {
                        Text(who).font(.system(size: 12)).foregroundStyle(Theme.sub)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Theme.card, in: .rect(cornerRadius: 14))
        } else {
            StepLine(step: step)
        }
    }
}

#if DEBUG
#Preview("進めている丸太") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let log = useCase.allSteps().compactMap(\.log).first { $0.title == "確定申告" } ?? useCase.allSteps().first!.log!
    return NavigationStack { LogDetailView(logID: log.uuid) }
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("見つからない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    return NavigationStack { LogDetailView(logID: UUID()) }
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}
#endif

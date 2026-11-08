import SwiftData
import SwiftUI

/// 丸太の中身。薪を「誰の番か」で分けて並べる。じぶんの薪は「この1本だけ」、カジリの薪は受け取る画面へ
struct LogDetailView: View {
    let logID: UUID
    /// 丸太のタブの右の列に埋めこんで出しているか（横に広い画面）。そのときはタイトルの出し方を変えず、右下の＋のぶん下を空ける
    let isEmbedded: Bool

    @Environment(CalendarUseCase.self) private var calendar
    @Environment(LogUseCase.self) private var useCase
    @Query private var logs: [Log]
    @State private var deadlineRequest: EventEditorRequest?

    init(logID: UUID, isEmbedded: Bool) {
        self.logID = logID
        self.isEmbedded = isEmbedded
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
        .modifier(InlineTitleUnlessEmbedded(isEmbedded: isEmbedded))
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
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                LogHeader(log: log) { deadlineControl(log) }
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
                    StepSection(title: "やらない", steps: dropped, isLink: true)
                }
                if !log.memo.isEmpty {
                    SectionBox(title: "投げたメモ", detail: nil) {
                        Text(log.memo)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .textSelection(.enabled)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, isEmbedded ? 110 : 40)
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

/// 丸太の画面として開いたときだけ、タイトルを小さくする（埋めこんだときは、丸太のタブのタイトルをそのまま使う）
private struct InlineTitleUnlessEmbedded: ViewModifier {
    let isEmbedded: Bool

    func body(content: Content) -> some View {
        if isEmbedded {
            content
        } else {
            content.navigationBarTitleDisplayMode(.inline)
        }
    }
}

/// 丸太の名前・締め切り・なぜやるか・進み具合。この画面の主役なので、1つの白い箱にまとめる
private struct LogHeader<Accessory: View>: View {
    let log: Log
    @ViewBuilder let accessory: Accessory

    var body: some View {
        let total = log.steps.filter { $0.quadrant != .drop }.count
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if let deadline = log.deadline {
                        Text("\(deadline, format: .dateTime.month().day().weekday())まで")
                            .font(.system(size: 12, weight: .heavy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Theme.amber, in: .capsule)
                    }
                    Text(log.title)
                        .font(.system(size: 26, weight: .black))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                KajiriImage(pose: log.isFinished ? .dam : .gnaw, size: 56)
            }
            if !log.kajiriComment.isEmpty {
                Text(log.kajiriComment)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.ink)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(log.doneCount)").font(.system(size: 22, weight: .black))
                    Text("/ \(total)本 片づいた").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
                }
                ProgressPips(total: total, done: log.doneCount)
            }
            if !log.why.isEmpty {
                Label(log.why, systemImage: "sparkles")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            accessory
        }
        .padding(18)
        .background(.white, in: .rect(cornerRadius: 24))
    }
}

/// 見出しと薪の行を、1つの箱にまとめる
private struct StepSection: View {
    let title: LocalizedStringKey
    let steps: [Step]
    /// 押して「この1本だけ」に行けるか
    let isLink: Bool

    var body: some View {
        SectionBox(title: title, detail: String(localized: "\(steps.count)本")) {
            BoxRows(items: steps) { step in
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
            WaitingStepRow(step: step)
        } else {
            StepLine(step: step, showsChevron: isLink)
        }
    }
}

#if DEBUG
#Preview("進めている丸太") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let log = useCase.allSteps().compactMap(\.log).first { $0.title == "確定申告" } ?? useCase.allSteps().first!.log!
    return NavigationStack { LogDetailView(logID: log.uuid, isEmbedded: false) }
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("見つからない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    return NavigationStack { LogDetailView(logID: UUID(), isEmbedded: false) }
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}
#endif

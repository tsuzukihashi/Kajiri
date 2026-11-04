import SwiftData
import SwiftUI

/// 丸太の一覧。丸太ごとに、どこまで進んだか・いま誰の番かを並べて見せる
struct LogsSheet: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(LogUseCase.self) private var useCase
    @Query(sort: \Log.createdAt, order: .reverse) private var logs: [Log]
    @State private var editor: DeadlineEditor?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("丸太").font(.system(size: 20, weight: .black))
                    Text("\(logs.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.sub)
                        .padding(.horizontal, 8)
                        .background(Theme.chip, in: .capsule)
                }
                if logs.isEmpty {
                    ContentUnavailableView(
                        "まだ丸太がありません",
                        systemImage: "tray",
                        description: Text("ホームの＋から、気になっていることを投げてください。カジリが小さくかじります。")
                    )
                }
                ForEach(logs) { log in
                    LogCard(
                        log: log,
                        canAddToCalendar: calendar.access == .granted,
                        onAddDeadline: {
                            if let request = calendar.deadlineRequest(for: log) {
                                editor = DeadlineEditor(log: log, request: request)
                            }
                        }
                    )
                }
            }
            .padding(16)
        }
        .background(Theme.card)
        .sheet(item: $editor) { target in
            EventEditorView(request: target.request) { savedID in
                if let savedID { useCase.markDeadlineInCalendar(target.log, eventIdentifier: savedID) }
                editor = nil
            }
            .ignoresSafeArea()
        }
    }
}

/// 締め切りを iPhone のカレンダーに入れる画面を開いている丸太
private struct DeadlineEditor: Identifiable {
    let log: Log
    let request: EventEditorRequest
    var id: UUID { request.id }
}

private struct LogCard: View {
    let log: Log
    let canAddToCalendar: Bool
    let onAddDeadline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(log.title).font(.system(size: 16, weight: .heavy))
                Spacer()
                if let deadline = log.deadline {
                    Text(deadline, format: .dateTime.month().day())
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
            }
            ProgressPips(total: log.steps.count, done: log.doneCount)
            if let next = log.nextStep {
                HStack(spacing: 6) {
                    Text(turnLabel(next)).font(.system(size: 13, weight: .bold))
                    Text(next.title).font(.system(size: 13))
                }
            } else {
                Text("全部片づいた。いいダムだ。").font(.system(size: 13, weight: .bold))
            }
            if !log.why.isEmpty {
                Text(log.why).font(.system(size: 12)).foregroundStyle(Theme.sub)
            }
            deadlineRow
        }
        .padding(14)
        .background(Theme.ground, in: .rect(cornerRadius: 18))
    }

    /// 締め切りを iPhone のカレンダーに入れる（入れたら、入っていることだけ見せる）
    @ViewBuilder
    private var deadlineRow: some View {
        if log.deadline != nil && !log.isFinished {
            if log.deadlineEventID != nil {
                Label("締め切りはカレンダーに入っています", systemImage: "calendar.badge.checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.sub)
            } else if canAddToCalendar {
                Button(action: onAddDeadline) {
                    Label("締め切りをカレンダーに入れる", systemImage: "calendar.badge.plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 36)
                        .background(Theme.chip, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func turnLabel(_ step: Step) -> String {
        switch step.owner {
        case .me: String(localized: "じぶんの番")
        case .kajiri: String(localized: "カジリの番")
        case .other: String(localized: "仲間に頼む")
        case .wait: String(localized: "待ち")
        }
    }
}

/// 片づいた薪の数（残りの数より、積み上がった分を見せる）
private struct ProgressPips: View {
    let total: Int
    let done: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < done ? Theme.ink : Theme.line)
                    .frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(total)本のうち\(done)本済み"))
    }
}

#if DEBUG
#Preview("丸太がある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    LogsSheet()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("空") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    LogsSheet()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}
#endif

import SwiftUI

/// 予定のすき間（空き時間）。今日なら、カジリが置いた薪とカジリの仕事を並べる
struct TimelineFreeRow: View {
    let slot: DayPlanner.FreeSlot
    let now: Date
    let isNow: Bool
    /// 今日いちばん早い空き時間（カジリの仕事と、ほかに置くものが無いときの一言を出す）
    let isHost: Bool
    let steps: [Step]
    let kajiriSteps: [Step]
    let hasLogs: Bool
    let onThrow: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeLabel
                .frame(width: 58, alignment: .trailing)
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                header
                ForEach(steps) { step in
                    if step.isDone {
                        StepChip(title: step.title, minutes: step.minutes, isDone: true)
                    } else {
                        NavigationLink(value: Route.focus(step.uuid)) {
                            StepChip(title: step.title, minutes: step.minutes, isDone: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                ForEach(kajiriSteps) { step in
                    NavigationLink(value: Route.handoff(step.uuid)) {
                        KajiriChip(step: step)
                    }
                    .buttonStyle(.plain)
                }
                if isHost {
                    hostNote
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 空き時間は「何も入っていない時間」なので、予定（白い箱）と違って点線の枠で見せる
            .background(Theme.freeTime.opacity(0.5), in: .rect(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.sub.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
        }
    }

    @ViewBuilder
    private var timeLabel: some View {
        if isNow {
            Text(CalendarUseCase.clock(now))
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.amber, in: .rect(cornerRadius: 6))
        } else {
            Text(CalendarUseCase.clock(slot.start))
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
    }

    @ViewBuilder
    private var header: some View {
        if slot.isOverflow {
            Label("今日の薪", systemImage: "clock")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Label("空き時間", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                Spacer()
                Text("〜\(CalendarUseCase.clock(slot.end))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.sub)
            }
            DurationText(minutes: Int((slot.end.timeIntervalSince(isNow ? now : slot.start)) / 60))
        }
    }

    /// 今日の空き時間に、ほかに置くものが無いときの一言
    @ViewBuilder
    private var hostNote: some View {
        if !hasLogs {
            VStack(alignment: .leading, spacing: 8) {
                Text("気になってることを投げておくと、カジリが薪にして、ここに置きます。")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                Button(action: onThrow) {
                    Label("丸太を投げる", systemImage: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(.white, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        } else if steps.isEmpty && kajiriSteps.isEmpty {
            Text("いま、じぶんの番の薪はありません。")
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
        }
    }
}

/// 「2時間 30分」の大きな数字
private struct DurationText: View {
    let minutes: Int

    var body: some View {
        let value = max(0, minutes)
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            if value >= 60 {
                Text("\(value / 60)").font(.system(size: 26, weight: .black))
                Text("時間").font(.system(size: 13, weight: .bold)).padding(.trailing, 6)
            }
            Text("\(value % 60)").font(.system(size: 26, weight: .black))
            Text("分").font(.system(size: 13, weight: .bold))
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("いまの空き時間") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps()
    NavigationStack {
        TimelineFreeRow(
            slot: DayPlanner.FreeSlot(start: .now, end: .now.addingTimeInterval(5400), isOverflow: false),
            now: .now,
            isNow: true,
            isHost: true,
            steps: Array(steps.filter { $0.owner == .me }.prefix(2)),
            kajiriSteps: steps.filter { $0.owner == .kajiri },
            hasLogs: true,
            onThrow: {}
        )
        .padding()
        .background(Theme.ground)
    }
    .modelContainer(container)
}

#Preview("丸太がまだない") {
    let (_, container) = LogUseCase.preview(filled: false)
    TimelineFreeRow(
        slot: DayPlanner.FreeSlot(start: .now, end: .now.addingTimeInterval(3000), isOverflow: false),
        now: .now,
        isNow: true,
        isHost: true,
        steps: [],
        kajiriSteps: [],
        hasLogs: false,
        onThrow: {}
    )
    .padding()
    .background(Theme.ground)
    .modelContainer(container)
}
#endif

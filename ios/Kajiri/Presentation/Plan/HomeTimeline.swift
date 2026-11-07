import SwiftUI

/// 起床から就寝までの線。予定と、予定のすき間（空き時間）を時刻順に並べ、
/// 今日なら空き時間にカジリが今日の薪を置く
struct HomeTimeline: View {
    let items: [DayPlanner.Item]
    let now: Date
    let isToday: Bool
    /// 今日片づけた薪（最初の空き時間に、チェック済みで出す）
    let doneSteps: [Step]
    let kajiriSteps: [Step]
    let hasLogs: Bool
    let onEventTap: (CalendarEvent) -> Void
    let onThrow: () -> Void

    var body: some View {
        // 片づけた薪・カジリの仕事は、今日いちばん早い空き時間に置く（いまが予定の最中でも見えるように）
        let hostID = isToday ? items.first(where: { if case .free = $0 { true } else { false } })?.id : nil
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items) { item in
                row(item, isHost: item.id == hostID)
            }
        }
        .padding(.trailing, 18)
        .background(alignment: .leading) {
            Rectangle()
                .fill(Theme.line)
                .frame(width: 2)
                .padding(.leading, 66)
                .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private func row(_ item: DayPlanner.Item, isHost: Bool) -> some View {
        switch item {
        case let .wake(date):
            TimelineAnchorRow(time: CalendarUseCase.clock(date), title: "起床", symbol: "sun.max")
        case let .sleep(date):
            TimelineAnchorRow(time: CalendarUseCase.clock(date), title: "就寝", symbol: "bed.double")
        case let .event(event, isPast):
            Button { onEventTap(event) } label: {
                TimelineEventRow(event: event, isPast: isPast)
            }
            .buttonStyle(.plain)
        case let .free(slot, isNow, steps):
            TimelineFreeRow(
                slot: slot,
                now: now,
                isNow: isNow,
                isHost: isHost,
                steps: isHost ? doneSteps + steps : steps,
                kajiriSteps: isHost ? kajiriSteps : [],
                hasLogs: hasLogs,
                onThrow: onThrow
            )
        }
    }
}

#if DEBUG
#Preview("予定と薪") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps()
    let picks = TodayPicker.pick(from: steps, now: .now, limit: 3)
    ScrollView {
        HomeTimeline(
            items: DayPlanner.plan(day: .now, now: .now, events: CalendarEvent.previewWeek(now: .now), steps: picks.open),
            now: .now,
            isToday: true,
            doneSteps: picks.done,
            kajiriSteps: steps.filter { $0.owner == .kajiri },
            hasLogs: true,
            onEventTap: { _ in },
            onThrow: {}
        )
    }
    .background(Theme.ground)
    .modelContainer(container)
}

#Preview("カレンダーだけ") {
    let (_, container) = LogUseCase.preview(filled: false)
    ScrollView {
        HomeTimeline(
            items: DayPlanner.plan(day: .now, now: .now, events: CalendarEvent.previewWeek(now: .now), steps: []),
            now: .now,
            isToday: true,
            doneSteps: [],
            kajiriSteps: [],
            hasLogs: false,
            onEventTap: { _ in },
            onThrow: {}
        )
    }
    .background(Theme.ground)
    .modelContainer(container)
}
#endif

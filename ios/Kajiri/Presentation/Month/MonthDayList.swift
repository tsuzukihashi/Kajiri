import SwiftUI

/// 月の表で選んだ日の中身: 予定・丸太の締め切り・その日が期限の薪
struct MonthDayList: View {
    let day: Date
    let events: [CalendarEvent]
    let deadlines: [Log]
    let dueSteps: [Step]
    let canAddEvent: Bool
    let onEventTap: (CalendarEvent) -> Void
    let onAddEvent: () -> Void

    var body: some View {
        let isEmpty = events.isEmpty && deadlines.isEmpty && dueSteps.isEmpty
        SectionBox(
            titleText: Text(day, format: .dateTime.month().day().weekday()),
            detail: isEmpty ? nil : String(localized: "\(events.count + deadlines.count + dueSteps.count)件")
        ) {
            BoxRows(items: events) { event in
                Button { onEventTap(event) } label: {
                    MonthEventRow(event: event)
                }
                .buttonStyle(.plain)
            }
            if !events.isEmpty && !deadlines.isEmpty { BoxDivider() }
            BoxRows(items: deadlines) { log in
                HStack(spacing: 10) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 13))
                        .frame(width: 26, height: 26)
                        .background(Theme.amber, in: .rect(cornerRadius: 7))
                    Text("締め切り: \(log.title)").font(.system(size: 15, weight: .bold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.ink)
                .padding(14)
            }
            if !(events.isEmpty && deadlines.isEmpty) && !dueSteps.isEmpty { BoxDivider() }
            BoxRows(items: dueSteps) { step in
                NavigationLink(value: Route.focus(step.uuid)) {
                    StepLine(step: step, showsChevron: true)
                }
                .buttonStyle(.plain)
            }
            if isEmpty {
                emptyNote
            }
            if canAddEvent {
                BoxDivider()
                Button(action: onAddEvent) {
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 26)
                        Text("この日に予定を足す").font(.system(size: 15, weight: .bold))
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(14)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("この日の予定はありません").font(.system(size: 15, weight: .bold))
            Text(canAddEvent
                 ? String(localized: "下の「この日に予定を足す」で入れると、iPhone のカレンダーにも入ります。")
                 : String(localized: "カレンダーをつなぐと、iPhone に入れてある予定がここに並びます。"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 月の表の下に並べる予定1件（箱の中の行）
private struct MonthEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 5, height: 30).frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                Text(event.isAllDay
                     ? String(localized: "終日")
                     : "\(CalendarUseCase.clock(event.start))〜\(CalendarUseCase.clock(event.end))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.line)
        }
        .foregroundStyle(Theme.ink)
        .padding(14)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview("予定がある日") {
    let (_, container) = LogUseCase.preview(filled: false)
    NavigationStack {
        MonthDayList(
            day: .now, events: CalendarEvent.previewWeek(now: .now).prefix(3).map { $0 }, deadlines: [], dueSteps: [],
            canAddEvent: true, onEventTap: { _ in }, onAddEvent: {}
        )
        .padding()
        .background(Theme.ground)
    }
    .modelContainer(container)
}

#Preview("何もない日") {
    MonthDayList(day: .now, events: [], deadlines: [], dueSteps: [], canAddEvent: false, onEventTap: { _ in }, onAddEvent: {})
        .padding()
        .background(Theme.ground)
}
#endif

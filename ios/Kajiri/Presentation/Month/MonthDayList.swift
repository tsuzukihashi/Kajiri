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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(day, format: .dateTime.month().day().weekday())
                    .font(.system(size: 16, weight: .heavy))
                Spacer()
                if canAddEvent {
                    Button(action: onAddEvent) {
                        Label("予定を足す", systemImage: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                            .background(Theme.chip, in: .capsule)
                    }
                }
            }
            ForEach(events) { event in
                Button { onEventTap(event) } label: {
                    MonthEventRow(event: event)
                }
                .buttonStyle(.plain)
            }
            ForEach(deadlines) { log in
                Label("締め切り: \(log.title)", systemImage: "flag.fill")
                    .font(.system(size: 14, weight: .bold))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.amberSoft, in: .rect(cornerRadius: 14))
            }
            ForEach(dueSteps) { step in
                NavigationLink(value: Route.focus(step.uuid)) {
                    StepChip(title: step.title, minutes: step.minutes, isDone: false)
                }
                .buttonStyle(.plain)
            }
            if events.isEmpty && deadlines.isEmpty && dueSteps.isEmpty {
                emptyNote
            }
        }
    }

    private var emptyNote: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("この日の予定はありません").font(.system(size: 14, weight: .bold))
            Text(canAddEvent
                 ? String(localized: "右上の「予定を足す」で入れると、iPhone のカレンダーにも入ります。")
                 : String(localized: "カレンダーをつなぐと、iPhone に入れてある予定がここに並びます。"))
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: .rect(cornerRadius: 14))
    }
}

/// 月の表の下に並べる予定1件
private struct MonthEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2).fill(event.color).frame(width: 4, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.system(size: 14, weight: .bold)).lineLimit(1)
                Text(event.isAllDay
                     ? String(localized: "終日")
                     : "\(CalendarUseCase.clock(event.start))〜\(CalendarUseCase.clock(event.end))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
        }
        .foregroundStyle(Theme.ink)
        .padding(10)
        .background(.white, in: .rect(cornerRadius: 14))
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

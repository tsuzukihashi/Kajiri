import SwiftData
import SwiftUI

/// 月の予定。iPhone のカレンダーとつないだ Google カレンダーの予定、丸太の締め切り・その日が期限の薪を並べる
struct MonthView: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(AppRouter.self) private var router
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]

    @State private var month = AppClock.now
    @State private var selectedDay = AppClock.now
    @State private var selectedEvent: CalendarEvent?
    @State private var editor: EventEditorRequest?

    var body: some View {
        @Bindable var router = router
        let now = AppClock.now
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                MonthHeader(month: month, onMove: move)
                if !calendar.canReadEvents {
                    CalendarConnectCard(access: calendar.access) {
                        Task { await calendar.requestAccess() }
                    }
                    .padding(.horizontal, -18)
                }
                MonthGrid(
                    month: month,
                    selected: selectedDay,
                    now: now,
                    dots: dots(),
                    deadlineDays: Set(openDeadlineLogs().compactMap { $0.deadline.map(JapanDate.dayString) }),
                    onSelect: { selectedDay = $0 }
                )
                .padding(12)
                .background(.white, in: .rect(cornerRadius: 22))
                MonthDayList(
                    day: selectedDay,
                    events: calendar.events(on: selectedDay),
                    deadlines: openDeadlineLogs().filter { log in log.deadline.map { JapanDate.isSameDay($0, selectedDay) } ?? false },
                    dueSteps: steps.filter { step in
                        !step.isDone && step.owner == .me && (step.due.map { JapanDate.isSameDay($0, selectedDay) } ?? false)
                    },
                    canAddEvent: calendar.access == .granted,
                    onEventTap: { selectedEvent = $0 },
                    onAddEvent: { editor = calendar.newEventRequest(on: selectedDay, now: now) }
                )
            }
            .padding(18)
        }
        .background(Theme.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // 開いた月をまだ読んでいなければ Google から読む
        .task(id: "\(JapanDate.dayString(month))|\(calendar.isGoogleConnected)") {
            let weeks = MonthGrid.weeks(of: month)
            guard let first = weeks.first?.first, let last = weeks.last?.last else { return }
            await calendar.loadGoogle(from: first, to: JapanDate.addingDays(1, to: last))
        }
        .sheet(item: $editor) { request in
            EventEditorView(request: request) { _ in editor = nil }
                .ignoresSafeArea()
        }
        .eventSheets(selected: $selectedEvent, throwRequest: $router.throwRequest)
    }

    private func move(_ months: Int) {
        let calendar = JapanDate.calendar
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = next
        // 今月に戻ったら今日、ほかの月なら1日を選ぶ
        if calendar.isDate(next, equalTo: AppClock.now, toGranularity: .month) {
            selectedDay = AppClock.now
        } else {
            selectedDay = calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? next
        }
    }

    private func dots() -> [String: [Color]] {
        let weeks = MonthGrid.weeks(of: month)
        guard let first = weeks.first?.first, let last = weeks.last?.last else { return [:] }
        var dots: [String: [Color]] = [:]
        for event in calendar.events(from: first, to: JapanDate.addingDays(1, to: last)) {
            var day = JapanDate.startOfDay(max(event.start, first))
            let end = event.end.addingTimeInterval(-1)
            while day <= end && day <= last {
                dots[JapanDate.dayString(day), default: []].append(event.color)
                day = JapanDate.addingDays(1, to: day)
            }
        }
        return dots
    }

    /// まだ終わっていない丸太の締め切り（iPhone のカレンダーに入れたものは予定として出るので除く）
    private func openDeadlineLogs() -> [Log] {
        logs.filter { $0.deadline != nil && $0.deadlineEventID == nil && !$0.isFinished }
    }

}

/// 「2026年11月」と、前の月・次の月
private struct MonthHeader: View {
    let month: Date
    let onMove: (Int) -> Void

    var body: some View {
        let calendar = JapanDate.calendar
        HStack(alignment: .bottom) {
            HStack(alignment: .bottom, spacing: 6) {
                Text("\(calendar.component(.month, from: month))月").font(.system(size: 34, weight: .black))
                Text(verbatim: "\(calendar.component(.year, from: month))")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .padding(.bottom, 5)
            }
            Spacer()
            Button { onMove(-1) } label: {
                Image(systemName: "chevron.left").frame(width: 44, height: 44).background(Theme.chip, in: .circle)
            }
            .accessibilityLabel(Text("前の月"))
            Button { onMove(1) } label: {
                Image(systemName: "chevron.right").frame(width: 44, height: 44).background(Theme.chip, in: .circle)
            }
            .accessibilityLabel(Text("次の月"))
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(Theme.ink)
    }
}

#if DEBUG
#Preview("予定がある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    NavigationStack { MonthView() }
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .environment(AppRouter())
        .modelContainer(container)
}

#Preview("カレンダーなし") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    NavigationStack { MonthView() }
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .notDetermined))
        .environment(AppRouter())
        .modelContainer(container)
}
#endif

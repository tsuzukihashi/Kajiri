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
        // 横に広い画面では、左に月の表、右に選んだ日の予定
        AdaptiveColumns(topPadding: 18, bottomPadding: 18) {
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
                dots: MonthGrid.dots(month: month, calendar: calendar),
                deadlineDays: MonthGrid.deadlineDays(logs: logs),
                onSelect: { selectedDay = $0 }
            )
            .padding(12)
            .background(.white, in: .rect(cornerRadius: 22))
        } trailing: {
            MonthDayList(
                day: selectedDay,
                events: calendar.events(on: selectedDay),
                deadlines: MonthGrid.openDeadlineLogs(logs).filter { log in log.deadline.map { JapanDate.isSameDay($0, selectedDay) } ?? false },
                dueSteps: steps.filter { step in
                    !step.isDone && step.owner == .me && (step.due.map { JapanDate.isSameDay($0, selectedDay) } ?? false)
                },
                canAddEvent: calendar.access == .granted,
                onEventTap: { selectedEvent = $0 },
                onAddEvent: { editor = calendar.newEventRequest(on: selectedDay, now: now) }
            )
        }
        .background(Theme.ground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .keepsBarsInSplit()
        .loadsGoogleMonth(month)
        .sheet(item: $editor) { request in
            EventEditorView(request: request) { _ in editor = nil }
                .ignoresSafeArea()
        }
        .eventSheets(selected: $selectedEvent, throwRequest: $router.throwRequest)
    }

    private func move(_ months: Int) {
        (month, selectedDay) = MonthGrid.moving(month, by: months)
    }
}

/// 「2026年11月」と、前の月・次の月
struct MonthHeader: View {
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

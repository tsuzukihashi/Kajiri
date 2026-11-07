import SwiftData
import SwiftUI

/// 予定のタブ。選んだ日の予定と、予定のすき間（空き時間）を時刻順に並べる。今日なら、すき間にカジリが今日の薪を置く。
/// 月の表示・予定を足す・準備が要りそうな予定を探す・カレンダーの設定は、ナビバーから開く
struct PlanView: View {
    #if DEBUG
    /// App Store のスクリーンショット用: 開いたときに「準備が要りそうな予定を探す」を出す
    nonisolated(unsafe) static var opensPrepScanOnAppear = false
    #endif

    @Environment(CalendarUseCase.self) private var calendar
    @Environment(AppRouter.self) private var router
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]

    @State private var selectedDay = AppClock.now
    @State private var selectedEvent: CalendarEvent?
    @State private var editor: EventEditorRequest?
    @State private var showsPrepScan = false
    @State private var showsSettings = false

    var body: some View {
        @Bindable var router = router
        let now = AppClock.now
        let isToday = JapanDate.isSameDay(selectedDay, now)
        NavigationStack(path: $router.planPath) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WeekStrip(selected: selectedDay, now: now, marks: weekMarks()) { selectedDay = $0 }
                    if !calendar.canReadEvents {
                        CalendarConnectCard(access: calendar.access) {
                            Task { await calendar.requestAccess() }
                        }
                    }
                    dayContent(now: now, isToday: isToday)
                }
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
            .background(Theme.ground)
            .navigationTitle(Text(selectedDay, format: .dateTime.month().day().weekday()))
            .toolbar { toolbar(now: now, isToday: isToday) }
            .routeDestinations()
        }
        .sheet(isPresented: $showsPrepScan) {
            PrepScanSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsSettings) {
            CalendarSettingsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editor) { request in
            EventEditorView(request: request) { _ in editor = nil }
                .ignoresSafeArea()
        }
        .eventSheets(selected: $selectedEvent, throwRequest: $router.throwRequest)
        #if DEBUG
        .onAppear {
            if Self.opensPrepScanOnAppear {
                Self.opensPrepScanOnAppear = false
                showsPrepScan = true
            }
        }
        #endif
    }

    @ViewBuilder
    private func dayContent(now: Date, isToday: Bool) -> some View {
        let events = calendar.events(on: selectedDay)
        let picks = TodayPicker.pick(from: steps, now: now, limit: TodayPicker.dailyCount)
        DayBannerRow(
            allDay: events.filter(\.isAllDay),
            deadlines: deadlines(on: selectedDay),
            onEventTap: { selectedEvent = $0 }
        )
        if calendar.canReadEvents || isToday {
            HomeTimeline(
                items: DayPlanner.plan(day: selectedDay, now: now, events: events, steps: isToday ? picks.open : []),
                now: now,
                isToday: isToday,
                doneSteps: isToday ? picks.done : [],
                kajiriSteps: [],
                hasLogs: !logs.isEmpty,
                onEventTap: { selectedEvent = $0 },
                onThrow: { router.throwNew() }
            )
        }
    }

    @ToolbarContentBuilder
    private func toolbar(now: Date, isToday: Bool) -> some ToolbarContent {
        if !isToday {
            ToolbarItem(placement: .topBarLeading) {
                Button("今日") { selectedDay = now }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            NavigationLink(value: Route.month) {
                Label("月の予定", systemImage: "calendar")
            }
            Menu {
                if calendar.canReadEvents {
                    Button {
                        showsPrepScan = true
                    } label: {
                        Label("準備が要りそうな予定を探す", systemImage: "sparkles")
                    }
                }
                if calendar.access == .granted {
                    Button {
                        editor = calendar.newEventRequest(on: selectedDay, now: now)
                    } label: {
                        Label("予定を足す", systemImage: "calendar.badge.plus")
                    }
                }
                Button {
                    showsSettings = true
                } label: {
                    Label("カレンダーの設定", systemImage: "gearshape")
                }
            } label: {
                Label("ほかの操作", systemImage: "ellipsis")
            }
        }
    }

    /// その日が締め切りの丸太（iPhone のカレンダーに入れたものは、予定として出るので除く）
    private func deadlines(on day: Date) -> [Log] {
        logs.filter { log in
            guard let deadline = log.deadline, log.deadlineEventID == nil, !log.isFinished else { return false }
            return JapanDate.isSameDay(deadline, day)
        }
    }

    private func weekMarks() -> Set<String> {
        let week = JapanDate.week(containing: selectedDay)
        guard let first = week.first, let last = week.last else { return [] }
        var marks = calendar.busyDays(from: first, to: JapanDate.addingDays(1, to: last))
        for log in logs where !log.isFinished && log.deadlineEventID == nil {
            if let deadline = log.deadline { marks.insert(JapanDate.dayString(deadline)) }
        }
        return marks
    }
}

#if DEBUG
private struct PlanPreview: View {
    let access: CalendarAccess

    var body: some View {
        let (useCase, container) = LogUseCase.preview(filled: true)
        PlanView()
            .environment(useCase)
            .environment(CalendarUseCase.preview(access: access))
            .environment(AppRouter())
            .modelContainer(container)
    }
}

#Preview("予定がある") {
    PlanPreview(access: .granted)
}

#Preview("カレンダーをまだつないでいない") {
    PlanPreview(access: .notDetermined)
}
#endif

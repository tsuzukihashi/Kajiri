import SwiftData
import SwiftUI

/// ホーム。モードで中身ごと入れかえる。
/// - まだ何もない（丸太なし・カレンダーもつないでいない）: カジリと「丸太を投げる」
/// - 1日の線: 選んだ日の予定と、予定のすき間。今日なら、すき間にカジリが今日の薪を置く
/// - 今日の分が終わった: 伸びたダムと、このあとの予定
struct HomeView: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]

    @State private var path: [Route] = []
    @State private var throwRequest: ThrowRequest?
    @State private var showsLogs = false
    @State private var selectedDay = AppClock.now
    @State private var selectedEvent: CalendarEvent?
    @State private var editor: EventEditorRequest?
    /// 終わったあとに「もう1本だけ」を押した数
    @State private var extraCount = 0
    @AppStorage("finishedDay") private var finishedDay = ""

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Theme.ground)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .focus(id): FocusView(stepID: id)
                    case let .handoff(id): HandoffView(stepID: id)
                    case .matrix: MatrixView()
                    case .month: MonthView()
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $throwRequest) { request in
            ThrowSheet(request: request)
        }
        .sheet(isPresented: $showsLogs) {
            LogsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editor) { request in
            EventEditorView(request: request) { _ in editor = nil }
                .ignoresSafeArea()
        }
        .eventSheets(selected: $selectedEvent, throwRequest: $throwRequest)
        #if DEBUG
        .onAppear {
            // 確かめる・デモを撮るとき用: -demoThrow "メモ" で、メモを入れた投げるシートを開く
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-demoThrow"), index + 1 < arguments.count {
                throwRequest = ThrowRequest(memo: arguments[index + 1], sourceEventID: nil)
            }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            // 設定でカレンダーを許可して戻ってきたとき
            if phase == .active { calendar.refreshAccess() }
        }
    }

    @ViewBuilder
    private var content: some View {
        let now = AppClock.now
        let isToday = JapanDate.isSameDay(selectedDay, now)
        let picks = TodayPicker.pick(from: steps, now: now, limit: TodayPicker.dailyCount + extraCount)
        if logs.isEmpty && calendar.access != .granted {
            HomeEmptyView(
                access: calendar.access,
                onThrow: { throwNew() },
                onConnect: { Task { await calendar.requestAccess() } }
            )
        } else if isToday && (picks.isAllDone || finishedDay == JapanDate.dayString(now)) {
            HomeDoneView(
                doneToday: picks.done.count,
                damCount: steps.filter(\.isDone).count,
                upcoming: calendar.events(on: now).filter { !$0.isAllDay && $0.end > now },
                onEventTap: { selectedEvent = $0 },
                onMore: {
                    finishedDay = ""
                    extraCount += 1
                },
                onFinish: { finishedDay = JapanDate.dayString(now) }
            )
        } else {
            dayHome(picks: picks, now: now, isToday: isToday)
        }
    }

    private func dayHome(picks: TodayPicker.Picks, now: Date, isToday: Bool) -> some View {
        let events = calendar.events(on: selectedDay)
        return ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HomeHeader(
                        day: selectedDay,
                        isToday: isToday,
                        canAddEvent: calendar.access == .granted,
                        onToday: { selectedDay = now },
                        onAddEvent: { editor = calendar.newEventRequest(on: selectedDay, now: now) }
                    )
                    WeekStrip(selected: selectedDay, now: now, marks: weekMarks()) { selectedDay = $0 }
                    if calendar.access != .granted {
                        CalendarConnectCard(access: calendar.access) {
                            Task { await calendar.requestAccess() }
                        }
                    }
                    DayBannerRow(
                        allDay: events.filter(\.isAllDay),
                        deadlines: deadlines(on: selectedDay),
                        onEventTap: { selectedEvent = $0 }
                    )
                    HomeTimeline(
                        items: DayPlanner.plan(day: selectedDay, now: now, events: events, steps: isToday ? picks.open : []),
                        now: now,
                        isToday: isToday,
                        doneSteps: isToday ? picks.done : [],
                        kajiriSteps: isToday ? steps.filter { $0.owner == .kajiri && !$0.isDone } : [],
                        hasLogs: !logs.isEmpty,
                        onEventTap: { selectedEvent = $0 },
                        onThrow: { throwNew() }
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, 140)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // 丸太が1本も無い（カレンダーだけ使っている）ときは、空の一覧をのぞかせない
                if !logs.isEmpty {
                    LogsPeekBar(logs: logs.filter { !$0.isFinished }) { showsLogs = true }
                }
            }

            Button {
                throwNew()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Theme.ink, in: .circle)
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
            }
            .accessibilityLabel(Text("丸太を投げる"))
            .padding(.trailing, 20)
            .padding(.bottom, 110)
        }
    }

    private func throwNew() {
        throwRequest = ThrowRequest(memo: "", sourceEventID: nil)
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
#Preview("予定と薪") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    HomeView()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("カレンダーだけ") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    HomeView()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("カレンダーなし") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    HomeView()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .notDetermined))
        .modelContainer(container)
}

#Preview("まだ何もない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    HomeView()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .notDetermined))
        .modelContainer(container)
}
#endif

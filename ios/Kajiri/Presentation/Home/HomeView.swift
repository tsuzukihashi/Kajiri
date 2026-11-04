import SwiftData
import SwiftUI

/// ホーム。モードで中身ごと入れかえる。
/// - まだ何もない（丸太なし・カレンダーもつないでいない）: カジリと「丸太を投げる」
/// - 1日の線: 選んだ日の予定と、予定のすき間。今日なら、すき間にカジリが今日の薪を置く
/// - 今日の分が終わった: 伸びたダムと、このあとの予定
struct HomeView: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(LogUseCase.self) private var useCase
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]

    @State private var path: [Route] = []
    @State private var throwRequest: ThrowRequest?
    @State private var showsLogs = false
    @State private var showsWeekly = false
    /// 丸太の一覧から「週のふりかえり」を押したとき、一覧が閉じてから開く
    @State private var opensWeeklyAfterLogs = false
    @State private var selectedDay = AppClock.now
    @State private var selectedEvent: CalendarEvent?
    @State private var editor: EventEditorRequest?
    /// 終わったあとに「もう1本だけ」を押した数
    @State private var extraCount = 0
    @AppStorage("finishedDay") private var finishedDay = ""

    var body: some View {
        NavigationStack(path: $path) {
            // 中身がモードで入れかわっても、行き先を決める土台は同じものにしておく
            ZStack { content }
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
        .sheet(isPresented: $showsLogs, onDismiss: {
            if opensWeeklyAfterLogs {
                opensWeeklyAfterLogs = false
                showsWeekly = true
            }
        }) {
            LogsSheet {
                opensWeeklyAfterLogs = true
                showsLogs = false
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsWeekly) {
            WeeklySheet()
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $editor) { request in
            EventEditorView(request: request) { _ in editor = nil }
                .ignoresSafeArea()
        }
        .eventSheets(selected: $selectedEvent, throwRequest: $throwRequest)
        // 薪が1本片づいたら、手ごたえを返す（戻したときは鳴らさない）
        .sensoryFeedback(trigger: steps.filter(\.isDone).count) { old, new in new > old ? .success : nil }
        #if DEBUG
        .onAppear {
            // 確かめる・デモを撮るとき用: -demoThrow "メモ" で、メモを入れた投げるシートを開く
            let arguments = ProcessInfo.processInfo.arguments
            if let index = arguments.firstIndex(of: "-demoThrow"), index + 1 < arguments.count {
                let memo = arguments[index + 1]
                // -demoThrowAfter 4: ホームを見せてから開く（デモ動画用）
                let delay = arguments.firstIndex(of: "-demoThrowAfter").flatMap { $0 + 1 < arguments.count ? Double(arguments[$0 + 1]) : nil } ?? 0
                Task {
                    try? await Task.sleep(for: .seconds(delay))
                    throwRequest = ThrowRequest(memo: memo, sourceEventID: nil)
                }
            }
        }
        #endif
        .onChange(of: scenePhase, initial: true) { _, phase in
            // 設定でカレンダーを許可して戻ってきたとき
            if phase == .active {
                calendar.refreshAccess()
                // 共有シートから投げられたメモがあれば、投げるシートに入れて開く
                if throwRequest == nil, let memo = SharedInbox.pop() {
                    IntentInbox.shared.pendingThrow = memo
                }
            }
            // 閉じるときに、次の朝・締め切りの前の日・月曜の通知を入れ直す
            if phase == .background { Task { await useCase.rescheduleNotifications(now: AppClock.now) } }
        }
        // Siri・アクションボタン・ショートカットの「カジリに投げる」
        .onChange(of: IntentInbox.shared.pendingThrow, initial: true) { _, memo in
            guard let memo else { return }
            IntentInbox.shared.pendingThrow = nil
            path = []
            selectedDay = AppClock.now
            throwRequest = ThrowRequest(memo: memo, sourceEventID: nil)
        }
        .task(id: notificationSignature) {
            await useCase.rescheduleNotifications(now: AppClock.now)
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
        } else if path.isEmpty && isToday && (picks.isAllDone || finishedDay == JapanDate.dayString(now)) {
            // 「この1本だけ」が閉じきってから入れかえる（閉じる途中で入れかえると、開いていた画面が真っ白で残る）
            HomeDoneView(
                doneToday: picks.done.count,
                damCount: steps.filter(\.isDone).count,
                upcoming: calendar.events(on: now).filter { !$0.isAllDay && $0.end > now },
                onEventTap: { selectedEvent = $0 },
                onWeekly: { showsWeekly = true },
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

    /// 薪や丸太が増えた・片づいた・締め切りが変わったら、通知を入れ直す
    private var notificationSignature: String {
        "\(logs.count)-\(steps.count)-\(steps.filter(\.isDone).count)-\(steps.filter { $0.notBefore != nil }.count)"
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

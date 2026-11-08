import SwiftData
import SwiftUI

/// 今日のタブ。開いた人が知りたいのは「いま何を1つやればいいか」なので、モードで中身ごと入れかえる。
/// 予定の線・週の帯・丸太の一覧はここに出さない（予定のタブ・丸太のタブ）
struct TodayView: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(AppRouter.self) private var router
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]

    /// 終わったあとに「もう1本だけ」を押した数
    @State private var extraCount = 0
    /// いま出しているモード。開いている画面（この1本だけ）が閉じきってから入れかえる
    @State private var shownMode: TodayMode?
    @AppStorage("finishedDay") private var finishedDay = ""

    var body: some View {
        @Bindable var router = router
        let now = AppClock.now
        let picks = TodayPicker.pick(from: steps, now: now, limit: TodayPicker.dailyCount + extraCount)
        let actual = TodayMode.of(hasLogs: !logs.isEmpty, picks: picks, finishedToday: finishedDay == JapanDate.dayString(now))
        let mode = shownMode ?? actual
        NavigationStack(path: $router.todayPath) {
            content(mode: mode, picks: picks, now: now)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.ground)
                .navigationTitle(Text(now, format: .dateTime.month().day().weekday()))
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: Route.settings) {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(Text("設定"))
                    }
                }
                .keepsBarsInSplit()
                .routeDestinations()
        }
        .measureColumns()
        .onChange(of: actual, initial: true) { settle(actual) }
        .onChange(of: router.todayPath.isEmpty) { settle(actual) }
    }

    @ViewBuilder
    private func content(mode: TodayMode, picks: TodayPicker.Picks, now: Date) -> some View {
        switch mode {
        case .start:
            TodayStartPanel(
                access: calendar.access,
                onThrow: { router.throwNew() },
                onConnect: { Task { await calendar.requestAccess() } }
            )
        case .next:
            TodayNextPanel(
                picks: picks,
                inbox: inbox,
                hint: FreeTimeHint.make(events: calendar.events(on: now), now: now),
                onThrow: { router.throwNew() }
            )
        case .kajiri:
            TodayKajiriPanel(
                inbox: inbox,
                waiting: steps.filter { !$0.isDone && ($0.owner == .other || $0.owner == .wait) && $0.quadrant != .drop },
                postponed: steps.filter { !$0.isDone && $0.owner == .me && ($0.notBefore.map { $0 > now } ?? false) },
                onThrow: { router.throwNew() }
            )
        case .done:
            TodayDonePanel(
                doneToday: picks.done.count,
                totalDone: steps.filter(\.isDone).count,
                inbox: inbox,
                isClosed: finishedDay == JapanDate.dayString(now),
                hasMore: !TodayPicker.pick(from: steps, now: now, limit: TodayPicker.dailyCount + extraCount + 1).open.isEmpty,
                onWeekly: { router.showsWeekly = true },
                onMore: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        finishedDay = ""
                        extraCount += 1
                    }
                },
                onFinish: {
                    withAnimation(.spring(duration: 0.45, bounce: 0.25)) { finishedDay = JapanDate.dayString(now) }
                },
                onThrow: { router.throwNew() }
            )
        }
    }

    /// カジリの薪のうち、まだ受け取っていないもの
    private var inbox: [Step] {
        steps.filter { $0.owner == .kajiri && !$0.isDone }
    }

    /// 「この1本だけ」などを開いている間はモードを入れかえない（閉じる途中で入れかえると、開いていた画面が真っ白で残る）
    private func settle(_ actual: TodayMode) {
        guard router.todayPath.isEmpty else {
            if shownMode == nil { shownMode = actual }
            return
        }
        guard shownMode != actual else { return }
        withAnimation(.easeInOut(duration: 0.3)) { shownMode = actual }
    }
}

#if DEBUG
private struct TodayPreview: View {
    let filled: Bool
    let access: CalendarAccess

    var body: some View {
        let (useCase, container) = LogUseCase.preview(filled: filled)
        TodayView()
            .environment(useCase)
            .environment(CalendarUseCase.preview(access: access))
            .environment(AppRouter())
            .modelContainer(container)
    }
}

#Preview("いまの1本") {
    TodayPreview(filled: true, access: .granted)
}

#Preview("まだ何もない") {
    TodayPreview(filled: false, access: .notDetermined)
}
#endif

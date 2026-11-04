import SwiftData
import SwiftUI

/// ホーム。モードで中身ごと入れかえる。
/// - まだ何もない: カジリと「丸太を投げる」だけ
/// - 今日の薪がある: 1日の線の空き時間に、今日の薪とカジリの仕事を置く
/// - 今日の分が終わった: 伸びたダム
struct HomeView: View {
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]

    @State private var path: [Route] = []
    @State private var isThrowing = false
    @State private var showsLogs = false
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
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isThrowing) {
            ThrowSheet()
        }
        .sheet(isPresented: $showsLogs) {
            LogsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private var content: some View {
        let now = Date.now
        let picks = TodayPicker.pick(from: steps, now: now, limit: TodayPicker.dailyCount + extraCount)
        if logs.isEmpty {
            HomeEmptyView { isThrowing = true }
        } else if picks.isAllDone || finishedDay == JapanDate.dayString(now) {
            HomeDoneView(
                doneToday: picks.done.count,
                damCount: steps.filter(\.isDone).count,
                onMore: {
                    finishedDay = ""
                    extraCount += 1
                },
                onFinish: { finishedDay = JapanDate.dayString(now) }
            )
        } else {
            activeHome(picks: picks, now: now)
        }
    }

    private func activeHome(picks: TodayPicker.Picks, now: Date) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HomeHeader(now: now)
                    WeekStrip(now: now)
                    HomeTimeline(
                        now: now,
                        picks: picks,
                        kajiriSteps: steps.filter { $0.owner == .kajiri && !$0.isDone }
                    )
                }
                .padding(.top, 8)
                .padding(.bottom, 140)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                LogsPeekBar(logs: logs.filter { !$0.isFinished }) { showsLogs = true }
            }

            Button {
                isThrowing = true
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
}

#if DEBUG
#Preview("薪がある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    HomeView()
        .environment(useCase)
        .modelContainer(container)
}

#Preview("まだ何もない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    HomeView()
        .environment(useCase)
        .modelContainer(container)
}
#endif

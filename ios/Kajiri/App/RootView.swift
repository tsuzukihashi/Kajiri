import SwiftData
import SwiftUI

/// タブ3つ（今日・丸太・予定）と、アプリ全体で1つだけ出すシート（投げる・週のふりかえり）。
/// 通知の入れ直し・Siri や共有シートから届いたメモも、ここで受ける
struct RootView: View {
    @Environment(CalendarUseCase.self) private var calendar
    @Environment(LogUseCase.self) private var useCase
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Log.createdAt) private var logs: [Log]
    @Query(sort: \Step.order) private var steps: [Step]
    @State private var router = AppRouter()

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.tab) {
            Tab("今日", systemImage: "sun.max", value: AppRouter.Tab.today) {
                TodayView()
            }
            Tab("丸太", systemImage: "tray.full", value: AppRouter.Tab.logs) {
                LogsView()
            }
            Tab("予定", systemImage: "calendar", value: AppRouter.Tab.plan) {
                PlanView()
            }
        }
        .tint(Theme.ink)
        .environment(router)
        .sheet(item: $router.throwRequest) { request in
            ThrowSheet(request: request)
        }
        .sheet(isPresented: $router.showsWeekly) {
            WeeklySheet()
                .presentationDragIndicator(.visible)
        }
        // 薪が1本片づいたら、手ごたえを返す（戻したときは鳴らさない）
        .sensoryFeedback(trigger: steps.filter(\.isDone).count) { old, new in new > old ? .success : nil }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                // 設定でカレンダーを許可して戻ってきたとき
                calendar.refreshAccess()
                Task { await calendar.refreshGoogle(now: AppClock.now) }
                // 共有シートから投げられたメモがあれば、投げるシートに入れて開く
                if router.throwRequest == nil, let memo = SharedInbox.pop() {
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
            router.throwFromOutside(memo: memo)
        }
        .task(id: notificationSignature) {
            await useCase.rescheduleNotifications(now: AppClock.now)
        }
        #if DEBUG
        .onAppear { openDebugEntry() }
        #endif
    }

    /// 薪や丸太が増えた・片づいた・締め切りが変わったら、通知を入れ直す
    private var notificationSignature: String {
        "\(logs.count)-\(steps.count)-\(steps.filter(\.isDone).count)-\(steps.filter { $0.notBefore != nil }.count)"
    }

    #if DEBUG
    /// 確かめる・デモやスクリーンショットを撮るとき用の起動引数
    /// - -storeShot focus|handoff|checklist|plan|logs|monthView|month|matrix|weekly: その画面を直接開く
    /// - -demoThrow "メモ"（-demoThrowAfter 秒）: メモを入れた投げるシートを開く
    private func openDebugEntry() {
        if let shot = StoreShots.shot {
            let picks = TodayPicker.pick(from: steps, now: AppClock.now, limit: TodayPicker.dailyCount)
            switch shot {
            case "focus":
                if let step = picks.open.first(where: { $0.title.contains("見出し") }) ?? picks.open.first {
                    router.todayPath = [.focus(step.uuid)]
                }
            case "handoff":
                if let step = steps.first(where: { $0.owner == .kajiri && $0.workState == .ready && $0.title.contains("要点") }) {
                    router.todayPath = [.handoff(step.uuid)]
                }
            case "checklist":
                // カジリがチェックリストを作って届けたときの画面
                if let step = steps.first(where: { $0.owner == .kajiri && $0.workState == .ready }) {
                    step.workTitle = String(localized: "木工事完了の立会いで使うチェックリスト")
                    step.workBody = StoreShots.checklistSample
                    // 2つ確かめて、メモを1つ書いたところ
                    step.workProgressJSON = WorkProgress(toggled: ["4", "5"], notes: ["10": String(localized: "南側のベランダにつける")]).encoded()
                    router.todayPath = [.handoff(step.uuid)]
                }
            case "plan":
                router.tab = .plan
            case "logs":
                router.tab = .logs
            case "monthView":
                router.tab = .plan
                router.planPath = [.month]
            case "month":
                router.tab = .plan
                PlanView.opensPrepScanOnAppear = true
            case "matrix":
                router.tab = .logs
                LogsView.opensMatrixOnAppear = true
            case "weekly":
                router.showsWeekly = true
            default:
                break
            }
        }
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-demoThrow"), index + 1 < arguments.count {
            let memo = arguments[index + 1]
            let delay = arguments.firstIndex(of: "-demoThrowAfter").flatMap { $0 + 1 < arguments.count ? Double(arguments[$0 + 1]) : nil } ?? 0
            Task {
                try? await Task.sleep(for: .seconds(delay))
                router.throwRequest = ThrowRequest(memo: memo, sourceEventID: nil)
            }
        }
    }
    #endif
}

#if DEBUG
#Preview("丸太がある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    RootView()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .granted))
        .modelContainer(container)
}

#Preview("まだ何もない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    RootView()
        .environment(useCase)
        .environment(CalendarUseCase.preview(access: .notDetermined))
        .modelContainer(container)
}
#endif

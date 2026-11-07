import SwiftData
import SwiftUI

/// 丸太のタブ。投げたもの全部と、どこまで進んだか。丸太ごとに見るか、4象限で見るかを切りかえる
struct LogsView: View {
    enum Layout: Hashable {
        case logs
        case matrix
    }

    #if DEBUG
    /// App Store のスクリーンショット用: 開いたときに4象限にする
    nonisolated(unsafe) static var opensMatrixOnAppear = false
    #endif

    @Environment(AppRouter.self) private var router
    @Query(sort: \Log.createdAt, order: .reverse) private var logs: [Log]
    @State private var layout = Layout.logs

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.logsPath) {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("見かた", selection: $layout) {
                            Text("丸太ごと").tag(Layout.logs)
                            Text("4象限").tag(Layout.matrix)
                        }
                        .pickerStyle(.segmented)
                        switch layout {
                        case .logs: logList
                        case .matrix: MatrixBoard()
                        }
                        AboutLinks()
                            .padding(.top, 24)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
                ThrowButton { router.throwNew() }
            }
            .background(Theme.ground)
            .navigationTitle("丸太")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.showsWeekly = true } label: {
                        Label("週のふりかえり", systemImage: "chart.bar")
                    }
                }
            }
            .routeDestinations()
        }
        #if DEBUG
        .onAppear {
            if Self.opensMatrixOnAppear {
                Self.opensMatrixOnAppear = false
                layout = .matrix
            }
        }
        #endif
    }

    @ViewBuilder
    private var logList: some View {
        let open = logs.filter { !$0.isFinished }
        let finished = logs.filter(\.isFinished)
        if logs.isEmpty {
            ContentUnavailableView {
                Label("まだ丸太がありません", systemImage: "tray")
            } description: {
                Text("気になっていることを投げると、カジリがすぐ手が動く大きさの薪にかじって、ここに並べます。")
            } actions: {
                Button("丸太を投げる") { router.throwNew() }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(.top, 20)
        }
        ForEach(open) { log in
            NavigationLink(value: Route.log(log.uuid)) {
                LogRow(log: log)
            }
            .buttonStyle(.plain)
        }
        if !finished.isEmpty {
            Text("片づいた丸太")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.sub)
                .padding(.top, 10)
            ForEach(finished) { log in
                NavigationLink(value: Route.log(log.uuid)) {
                    LogRow(log: log)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 丸太1本の行。名前・締め切り・どこまで進んだか・次は誰の番か
struct LogRow: View {
    let log: Log

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(log.title)
                    .font(.system(size: 17, weight: .heavy))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if let deadline = log.deadline {
                    Text("\(deadline, format: .dateTime.month().day())まで")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.sub)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
            }
            ProgressPips(total: log.steps.filter { $0.quadrant != .drop }.count, done: log.doneCount)
            if let next = log.nextStep {
                HStack(spacing: 6) {
                    Text(Self.turnLabel(next))
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(next.owner == .kajiri ? Theme.amberSoft : Theme.chip, in: .capsule)
                    Text(next.title)
                        .font(.system(size: 13))
                        .lineLimit(1)
                }
            } else {
                Text("全部片づいた")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    static func turnLabel(_ step: Step) -> String {
        switch step.owner {
        case .me: String(localized: "次はじぶん")
        case .kajiri: String(localized: "カジリが作業中")
        case .other: String(localized: "頼む")
        case .wait: String(localized: "待ち")
        }
    }
}

/// 片づいた薪の数（残りの数より、積み上がった分を見せる）
struct ProgressPips: View {
    let total: Int
    let done: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < done ? Theme.ink : Theme.line)
                    .frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(total)本のうち\(done)本済み"))
    }
}

#if DEBUG
private struct LogsPreview: View {
    let filled: Bool

    var body: some View {
        let (useCase, container) = LogUseCase.preview(filled: filled)
        LogsView()
            .environment(useCase)
            .environment(CalendarUseCase.preview(access: .granted))
            .environment(AppRouter())
            .modelContainer(container)
    }
}

#Preview("丸太がある") {
    LogsPreview(filled: true)
}

#Preview("空") {
    LogsPreview(filled: false)
}
#endif

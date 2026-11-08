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
    /// 2列のとき、右の列に中身を出している丸太
    @State private var selectedLogID: UUID?

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.logsPath) {
            LogsBody(
                logs: logs,
                layout: $layout,
                selectedLogID: selectedLogID ?? defaultLogID,
                onSelect: { log in
                    selectedLogID = log.uuid
                    layout = .logs
                },
                onThrow: { router.throwNew() }
            )
            .background(Theme.ground)
            .navigationTitle("丸太")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.showsWeekly = true } label: {
                        Label("週のふりかえり", systemImage: "chart.bar")
                    }
                }
            }
            .keepsBarsInSplit()
            .routeDestinations()
        }
        .measureColumns()
        #if DEBUG
        .onAppear {
            if Self.opensMatrixOnAppear {
                Self.opensMatrixOnAppear = false
                layout = .matrix
            }
        }
        #endif
    }

    /// 選んでいないときは、進めている丸太のいちばん新しいもの
    private var defaultLogID: UUID? {
        logs.first(where: { !$0.isFinished })?.uuid ?? logs.first?.uuid
    }
}

/// 丸太のタブの中身。1列のときは一覧（押すと丸太の画面へ進む）、
/// 横に広い画面では左に一覧、右に選んだ丸太の中身か4象限を出す
private struct LogsBody: View {
    let logs: [Log]
    @Binding var layout: LogsView.Layout
    let selectedLogID: UUID?
    let onSelect: (Log) -> Void
    let onThrow: () -> Void

    @Environment(\.columnLayout) private var columns

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            switch columns {
            case .single:
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        picker
                        switch layout {
                        case .logs: logList(selection: nil)
                        case .matrix: MatrixBoard()
                        }
                        AboutLinks()
                            .padding(.top, Theme.sectionSpacing)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 4)
                    .padding(.bottom, 100)
                }
            case let .split(leading, gutter):
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            picker
                            logList(selection: layout == .logs ? selectedLogID : nil)
                            AboutLinks()
                                .padding(.top, Theme.sectionSpacing)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 4)
                        .padding(.bottom, 40)
                    }
                    .frame(width: leading)
                    Color.clear.frame(width: gutter)
                    trailingPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            // 丸太が無いときは、空の案内の「丸太を投げる」と重ねない
            if !logs.isEmpty {
                ThrowButton(action: onThrow)
            }
        }
    }

    private var picker: some View {
        Picker("見かた", selection: $layout) {
            Text("丸太ごと").tag(LogsView.Layout.logs)
            Text("4象限").tag(LogsView.Layout.matrix)
        }
        .pickerStyle(.segmented)
    }

    /// 右の列: 選んだ丸太の中身か、4象限
    @ViewBuilder
    private var trailingPane: some View {
        switch layout {
        case .matrix:
            ScrollView {
                MatrixBoard()
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 110)
            }
        case .logs:
            if let selectedLogID {
                LogDetailView(logID: selectedLogID, isEmbedded: true)
                    .id(selectedLogID)
            } else {
                ContentUnavailableView {
                    Label("丸太を選ぶと、ここに中身が出ます", systemImage: "sidebar.left")
                } description: {
                    Text("まだ丸太が無いときは、左の「丸太を投げる」から始めてください。")
                }
            }
        }
    }

    @ViewBuilder
    private func logList(selection: UUID?) -> some View {
        let open = logs.filter { !$0.isFinished }
        let finished = logs.filter(\.isFinished)
        if logs.isEmpty {
            ContentUnavailableView {
                Label("まだ丸太がありません", systemImage: "tray")
            } description: {
                Text("気になっていることを投げると、カジリがすぐ手が動く大きさの薪にかじって、ここに並べます。")
            } actions: {
                Button(action: onThrow) {
                    Text("丸太を投げる").padding(.horizontal, 32)
                }
                .buttonStyle(PrimaryButtonStyle())
                .fixedSize()
            }
            .padding(.top, 20)
        }
        let select: ((Log) -> Void)? = columns.isSplit ? onSelect : nil
        VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
            if !open.isEmpty {
                LogGroup(title: "進めている", logs: open, selectedID: selection, onSelect: select)
            }
            if !finished.isEmpty {
                LogGroup(title: "片づいた", logs: finished, selectedID: selection, onSelect: select)
            }
        }
        .padding(.top, 8)
    }
}

/// 見出しと、丸太のカードの並び。丸太は1本ずつが物なので、カードを分けて並べる
private struct LogGroup: View {
    let title: LocalizedStringKey
    let logs: [Log]
    /// 2列のとき、右の列に中身を出している丸太
    let selectedID: UUID?
    /// 2列のときは、押すと右の列に中身を出す。1列のときは nil（丸太の画面へ進む）
    let onSelect: ((Log) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title).font(.system(size: 18, weight: .black))
                Text("\(logs.count)本").font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.sub)
            }
            .padding(.horizontal, 4)
            ForEach(logs) { log in
                if let onSelect {
                    Button { onSelect(log) } label: {
                        LogRow(log: log)
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Theme.ink, lineWidth: selectedID == log.uuid ? 2.5 : 0)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedID == log.uuid ? .isSelected : [])
                } else {
                    NavigationLink(value: Route.log(log.uuid)) {
                        LogRow(log: log)
                    }
                    .buttonStyle(.plain)
                }
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
        .background(.white, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    static func turnLabel(_ step: Step) -> String {
        switch step.owner {
        case .me: String(localized: "次はじぶん")
        case .kajiri:
            switch step.workState {
            case .ready: String(localized: "カジリから届いた")
            case .failed: String(localized: "カジリがつまずいた")
            case .idle, .working: String(localized: "カジリが作業中")
            }
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

#Preview("2列（Duo を開いた内側）", traits: .fixedLayout(width: 951, height: 635)) {
    LogsPreview(filled: true)
        .environment(\.columnLayout, .split(leading: 455, gutter: 40))
}

#Preview("空") {
    LogsPreview(filled: false)
}
#endif

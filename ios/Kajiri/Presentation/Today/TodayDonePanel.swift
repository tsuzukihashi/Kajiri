import SwiftUI

/// 今日の分が終わったとき。片づけた本数を見せて、休むか続けるかを選んでもらう。
/// 「今日はおしまい」を押したら、カジリが「おつかれさま」と言って座り、選ぶところが「また明日」の札に変わる。
/// 押しても何も変わらない、を作らない（2026-11-08 に実機で「押しても何も動かない」と言われた）
struct TodayDonePanel: View {
    let doneToday: Int
    let totalDone: Int
    /// カジリの薪（届いたものがあれば、ここでも受け取れる）
    let inbox: [Step]
    /// 今日はおしまいにしたか
    let isClosed: Bool
    /// 今日やれる自分の薪が、まだ残っているか（無ければ「もう1本だけ」を出さない。押しても何も起きないので）
    let hasMore: Bool
    let onWeekly: () -> Void
    let onMore: () -> Void
    let onFinish: () -> Void
    let onThrow: () -> Void

    @Environment(\.columnLayout) private var layout

    var body: some View {
        switch layout {
        case .single:
            ScrollView {
                VStack(spacing: 4) {
                    celebration
                    if hasInbox {
                        KajiriInboxCard(steps: inbox)
                            .padding(.horizontal, 18)
                            .padding(.top, Theme.sectionSpacing)
                    }
                }
                .padding(.bottom, 16)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                choices
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(Theme.ground)
            }
        case let .split(leading, gutter):
            // 横に広い画面: 左に片づけた本数、右に届いたものと「おしまい／もう1本」
            HStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 4) { celebration }
                        .padding(.bottom, 16)
                }
                .frame(width: leading)
                Color.clear.frame(width: gutter)
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    if hasInbox {
                        ScrollView {
                            KajiriInboxCard(steps: inbox)
                                .padding(.top, 8)
                        }
                    } else {
                        Spacer()
                        Text("今日の分は、ここまで。休んでも、もう1本だけやっても大丈夫です。")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.sub)
                    }
                    choices
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var hasInbox: Bool {
        inbox.contains(where: { $0.workState == .ready || $0.workState == .failed })
    }

    /// 主役は「今日片づけた本数」。カジリはその上に小さく添える
    private var celebration: some View {
        VStack(alignment: .leading, spacing: 12) {
            KajiriSays(
                pose: isClosed ? .sit : .dam,
                text: isClosed ? String(localized: "おつかれさま。また明日。") : String(localized: "今日の\(doneToday)本、おわり。")
            )
            .id(isClosed)
            .transition(.opacity.combined(with: .move(edge: .leading)))
            Button(action: onWeekly) {
                DoneCountCard(totalDone: totalDone, doneToday: doneToday)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("週のふりかえりを開く"))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var choices: some View {
        Group {
            if isClosed {
                closedCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Button("今日はおしまい", action: onFinish).buttonStyle(PrimaryButtonStyle())
                    moreButton(label: String(localized: "もう1本だけ"))
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.45, bounce: 0.25), value: isClosed)
        .sensoryFeedback(.success, trigger: isClosed) { _, closed in closed }
    }

    /// 「今日はおしまい」を押したあと。明日どうなるかを言って、やっぱり続けたい人の道も残す
    private var closedCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.amber)
                VStack(alignment: .leading, spacing: 2) {
                    Text("今日はここまで")
                        .font(.system(size: 17, weight: .heavy))
                    Text("明日の分は、明日ここに並べておきます。")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(.white, in: .rect(cornerRadius: 20))
            moreButton(label: String(localized: "やっぱり、もう1本だけ"))
        }
    }

    /// 続ける道。今日やれる薪が残っていなければ、押しても何も起きないので「新しく投げる」にする
    @ViewBuilder
    private func moreButton(label: String) -> some View {
        if hasMore {
            Button(label, action: onMore)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 48)
        } else {
            VStack(spacing: 2) {
                Button("新しく投げる", action: onThrow)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .frame(minHeight: 44)
                Text("今日やれる薪は、もう残っていません。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
        }
    }
}

/// 今日片づけた本数（この画面の主役）と、これまでの本数
private struct DoneCountCard: View {
    let totalDone: Int
    let doneToday: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日片づけた薪").font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.sub)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(doneToday)").font(.system(size: 72, weight: .black)).monospacedDigit()
                Text("本").font(.system(size: 20, weight: .heavy))
            }
            ProgressPips(total: max(doneToday, 1), done: doneToday)
            HStack {
                Text("これまでに \(totalDone)本").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
                Spacer()
                Text("週のふりかえり").font(.system(size: 13, weight: .bold))
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.sub)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 22))
    }
}

#if DEBUG
#Preview("届いたものなし") {
    NavigationStack {
        TodayDonePanel(doneToday: 3, totalDone: 15, inbox: [], isClosed: false, hasMore: true, onWeekly: {}, onMore: {}, onFinish: {}, onThrow: {})
            .background(Theme.ground)
    }
}

#Preview("2列（Duo を開いた内側）", traits: .fixedLayout(width: 951, height: 635)) {
    NavigationStack {
        TodayDonePanel(doneToday: 3, totalDone: 15, inbox: [], isClosed: false, hasMore: true, onWeekly: {}, onMore: {}, onFinish: {}, onThrow: {})
            .background(Theme.ground)
    }
    .environment(\.columnLayout, .split(leading: 455, gutter: 40))
}

#Preview("今日はおしまいにした") {
    NavigationStack {
        TodayDonePanel(doneToday: 5, totalDone: 5, inbox: [], isClosed: true, hasMore: true, onWeekly: {}, onMore: {}, onFinish: {}, onThrow: {})
            .background(Theme.ground)
    }
}

#Preview("押して確かめる") {
    @Previewable @State var closed = false
    NavigationStack {
        TodayDonePanel(doneToday: 5, totalDone: 5, inbox: [], isClosed: closed, hasMore: false, onWeekly: {}, onMore: { closed = false }, onFinish: { closed = true }, onThrow: {})
            .background(Theme.ground)
    }
}

#Preview("届いたものがある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let inbox = useCase.allSteps().filter { $0.owner == .kajiri }
    return NavigationStack {
        TodayDonePanel(doneToday: 3, totalDone: 15, inbox: inbox, isClosed: false, hasMore: false, onWeekly: {}, onMore: {}, onFinish: {}, onThrow: {})
            .background(Theme.ground)
    }
    .modelContainer(container)
}
#endif

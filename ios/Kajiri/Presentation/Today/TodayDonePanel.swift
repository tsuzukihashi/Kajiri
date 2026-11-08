import SwiftUI

/// 今日の分が終わったとき。片づけた本数を見せて、休むか続けるかを選んでもらう
struct TodayDonePanel: View {
    let doneToday: Int
    let totalDone: Int
    /// カジリの薪（届いたものがあれば、ここでも受け取れる）
    let inbox: [Step]
    let onWeekly: () -> Void
    let onMore: () -> Void
    let onFinish: () -> Void

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

    private var celebration: some View {
        VStack(spacing: 4) {
            KajiriBubble(text: String(localized: "今日の\(doneToday)本、おわり。"))
                .padding(.top, 16)
            KajiriImage(pose: .dam, size: 220)
            Button(action: onWeekly) {
                DoneCountCard(totalDone: totalDone, doneToday: doneToday)
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("週のふりかえりを開く"))
        }
    }

    private var choices: some View {
        VStack(spacing: 8) {
            Button("今日はおしまい", action: onFinish).buttonStyle(PrimaryButtonStyle())
            Button("もう1本だけ", action: onMore)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 48)
        }
    }
}

/// これまでに片づけた薪の本数
private struct DoneCountCard: View {
    let totalDone: Int
    let doneToday: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("片づけた薪").font(.system(size: 13)).foregroundStyle(Theme.sub)
            Text("\(totalDone)").font(.system(size: 30, weight: .black))
            Text("本").font(.system(size: 13, weight: .bold))
            Spacer()
            Text("今日 +\(doneToday)")
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 9)
                .padding(.vertical, 3)
                .background(Theme.amber, in: .capsule)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.sub)
        }
        .foregroundStyle(Theme.ink)
        .padding(16)
        .background(.white, in: .rect(cornerRadius: 20))
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }
}

#if DEBUG
#Preview("届いたものなし") {
    NavigationStack {
        TodayDonePanel(doneToday: 3, totalDone: 15, inbox: [], onWeekly: {}, onMore: {}, onFinish: {})
            .background(Theme.ground)
    }
}

#Preview("2列（Duo を開いた内側）", traits: .fixedLayout(width: 951, height: 635)) {
    NavigationStack {
        TodayDonePanel(doneToday: 3, totalDone: 15, inbox: [], onWeekly: {}, onMore: {}, onFinish: {})
            .background(Theme.ground)
    }
    .environment(\.columnLayout, .split(leading: 455, gutter: 40))
}

#Preview("届いたものがある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let inbox = useCase.allSteps().filter { $0.owner == .kajiri }
    return NavigationStack {
        TodayDonePanel(doneToday: 3, totalDone: 15, inbox: inbox, onWeekly: {}, onMore: {}, onFinish: {})
            .background(Theme.ground)
    }
    .modelContainer(container)
}
#endif

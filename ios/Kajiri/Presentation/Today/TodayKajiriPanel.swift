import SwiftUI

/// 今日の自分の薪は無いが、丸太は進んでいるとき。いまは誰の番かを見せて、届いたものがあれば受け取ってもらう
struct TodayKajiriPanel: View {
    let inbox: [Step]
    /// 頼んだ・待っている薪
    let waiting: [Step]
    /// 「いまじゃない」で明日以降にまわした自分の薪
    let postponed: [Step]
    let onThrow: () -> Void

    @Environment(\.columnLayout) private var layout

    /// 横に広い画面では、左にカジリ、右に届いたものと頼んだ・待っている薪
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AdaptiveColumns(topPadding: 0, bottomPadding: 110) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("いま、じぶんの番の薪はありません")
                        .font(.system(size: 22, weight: .black))
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.sub)
                    KajiriSays(pose: .gnaw, text: String(localized: "いまは、おれの番。"))
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
            } trailing: {
                if !inbox.isEmpty {
                    KajiriInboxCard(steps: inbox)
                }
                if !waiting.isEmpty {
                    WaitingList(steps: waiting)
                }
                if layout.isSplit && inbox.isEmpty && waiting.isEmpty {
                    NothingWaitingNote()
                        .padding(.top, 12)
                }
            }
            ThrowButton(action: onThrow)
        }
    }

    private var message: String {
        if !postponed.isEmpty {
            return String(localized: "明日にまわした薪が\(postponed.count)本あります。気になることが増えたら、右下の＋から投げてください。")
        }
        return String(localized: "気になることが増えたら、右下の＋から投げてください。カジリが小さくかじります。")
    }
}

/// 2列のとき、右の列に置く。カジリから届くものも、頼んだ・待っている薪も無いとき
private struct NothingWaitingNote: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("届くもの・待っているものはありません")
                .font(.system(size: 16, weight: .heavy))
            Text("カジリの番の薪や、人に頼んだ薪があると、ここに並びます。")
                .font(.system(size: 14))
                .foregroundStyle(Theme.sub)
        }
        .foregroundStyle(Theme.ink)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 22))
    }
}

/// 頼んだ・待っている薪
private struct WaitingList: View {
    let steps: [Step]

    var body: some View {
        SectionBox(title: "頼んだ・待っている", detail: String(localized: "\(steps.count)本")) {
            BoxRows(items: steps) { step in
                WaitingStepRow(step: step)
            }
        }
    }
}

/// 頼む・待ちの薪の1行。だれに頼むかを2行目に
struct WaitingStepRow: View {
    let step: Step

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step.owner == .wait ? "hourglass" : "person.2")
                .font(.system(size: 15))
                .foregroundStyle(Theme.sub)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if step.owner == .wait { return String(localized: "返事待ち") }
        if let who = step.askWho, !who.isEmpty { return String(localized: "\(who)に頼む") }
        return String(localized: "だれかに頼む")
    }
}

#if DEBUG
#Preview("届いたものがある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps()
    return NavigationStack {
        TodayKajiriPanel(
            inbox: steps.filter { $0.owner == .kajiri },
            waiting: steps.filter { $0.owner == .other },
            postponed: [],
            onThrow: {}
        )
        .background(Theme.ground)
    }
    .modelContainer(container)
}

#Preview("何も無い") {
    let (_, container) = LogUseCase.preview(filled: false)
    return NavigationStack {
        TodayKajiriPanel(inbox: [], waiting: [], postponed: [], onThrow: {})
            .background(Theme.ground)
    }
    .modelContainer(container)
}
#endif

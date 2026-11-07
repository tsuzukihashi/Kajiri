import SwiftUI

/// 今日の自分の薪は無いが、丸太は進んでいるとき。いまは誰の番かを見せて、届いたものがあれば受け取ってもらう
struct TodayKajiriPanel: View {
    let inbox: [Step]
    /// 頼んだ・待っている薪
    let waiting: [Step]
    /// 「いまじゃない」で明日以降にまわした自分の薪
    let postponed: [Step]
    let onThrow: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(spacing: 6) {
                        KajiriImage(pose: .gnaw, size: 150)
                        Text("いま、じぶんの番の薪はありません")
                            .font(.system(size: 18, weight: .heavy))
                        Text(message)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.sub)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    if !inbox.isEmpty {
                        KajiriInboxCard(steps: inbox)
                    }
                    if !waiting.isEmpty {
                        WaitingList(steps: waiting)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 100)
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

/// 頼んだ・待っている薪
private struct WaitingList: View {
    let steps: [Step]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("頼んだ・待っている")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.sub)
            ForEach(steps) { step in
                HStack(spacing: 10) {
                    Image(systemName: step.owner == .wait ? "hourglass" : "person.2")
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.system(size: 15, weight: .bold))
                        if let who = step.askWho, !who.isEmpty {
                            Text(who).font(.system(size: 12)).foregroundStyle(Theme.sub)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Theme.card, in: .rect(cornerRadius: 14))
            }
        }
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

import SwiftUI

/// 今日の自分の薪があるとき。いまの1本を大きく1つだけ出し、残りとカジリから届いたものは下に小さく
struct TodayNextPanel: View {
    let picks: TodayPicker.Picks
    /// カジリの薪（作っている・届いた・つまずいた）
    let inbox: [Step]
    let hint: FreeTimeHint?
    let onThrow: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let first = picks.open.first {
                        NextStepCard(step: first, remaining: picks.open.count, hint: hint)
                    }
                    if picks.open.count > 1 || !picks.done.isEmpty {
                        TodayRestList(rest: Array(picks.open.dropFirst()), done: picks.done)
                    }
                    if !inbox.isEmpty {
                        KajiriInboxCard(steps: inbox)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            ThrowButton(action: onThrow)
        }
    }
}

/// いまの1本。押すと「この1本だけ」
struct NextStepCard: View {
    let step: Step
    /// 今日の残り（いまの1本を含む）
    let remaining: Int
    let hint: FreeTimeHint?

    var body: some View {
        NavigationLink(value: Route.focus(step.uuid)) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .bottom, spacing: 10) {
                    KajiriImage(pose: .hand, size: 64)
                    Text(remaining > 1 ? "まずはこれだけ。" : "今日はこれで最後。")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Color(white: 0.9))
                        .padding(.bottom, 8)
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let log = step.log {
                        Text(log.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(white: 0.7))
                    }
                    Text(step.title)
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text("\(step.minutes)分")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Theme.amber, in: .capsule)
                        if step.needsComputer {
                            Label("パソコン", systemImage: "laptopcomputer")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(white: 0.25), in: .capsule)
                        }
                    }
                    if !step.firstMotion.isEmpty {
                        Text("最初の動き: \(step.firstMotion)")
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.85))
                            .multilineTextAlignment(.leading)
                    }
                }
                if let hint {
                    Label(hint.text, systemImage: "clock")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(white: 0.85))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.2), in: .rect(cornerRadius: 12))
                }
                Text("はじめる")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: .rect(cornerRadius: 16))
            }
            .padding(18)
            .background(Theme.ink, in: .rect(cornerRadius: 26))
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("この1本だけの画面を開く"))
    }
}

/// いまの1本のあとに控えている薪と、今日片づけた薪
struct TodayRestList: View {
    let rest: [Step]
    let done: [Step]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !rest.isEmpty {
                Text("このあと")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
                ForEach(rest) { step in
                    NavigationLink(value: Route.focus(step.uuid)) {
                        StepLine(step: step)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !done.isEmpty {
                Text("今日 片づけた \(done.count)本")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .padding(.top, rest.isEmpty ? 0 : 6)
                ForEach(done) { step in
                    StepLine(step: step)
                }
            }
        }
    }
}

/// 薪の1行（丸や線で、済んだかどうかが分かる）
struct StepLine: View {
    let step: Step

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18))
                .foregroundStyle(step.isDone ? Theme.ink : Theme.sub)
            Text(step.title)
                .font(.system(size: 15, weight: .bold))
                .strikethrough(step.isDone)
                .foregroundStyle(step.isDone ? Theme.sub : Theme.ink)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Text("\(step.minutes)分")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.card, in: .rect(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("3本ある") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps()
    let picks = TodayPicker.pick(from: steps, now: .now, limit: 3)
    NavigationStack {
        TodayNextPanel(
            picks: picks,
            inbox: steps.filter { $0.owner == .kajiri },
            hint: FreeTimeHint(kind: .until(title: "歯医者", start: .now.addingTimeInterval(9_840), minutes: 164)),
            onThrow: {}
        )
        .background(Theme.ground)
    }
    .modelContainer(container)
}

#Preview("届いたものなし・予定なし") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let picks = TodayPicker.pick(from: useCase.allSteps(), now: .now, limit: 1)
    NavigationStack {
        TodayNextPanel(picks: picks, inbox: [], hint: nil, onThrow: {})
            .background(Theme.ground)
    }
    .modelContainer(container)
}
#endif

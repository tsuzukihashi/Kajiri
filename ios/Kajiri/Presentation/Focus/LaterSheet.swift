import SwiftUI

/// 「あとで」のとき。理由を選ぶと、理由に合った直し方をする。消えたりはしない
struct LaterSheet: View {
    let step: Step
    /// 閉じるとき。true なら「この1本だけ」も閉じてホームに戻る
    let onClose: (Bool) -> Void

    @Environment(LogUseCase.self) private var useCase
    @State private var viewModel = LaterViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    KajiriImage(pose: .think, size: 64)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("あとで、だな。").font(.system(size: 20, weight: .heavy))
                        Text("どれがいちばん近い？ 消えたりはしないよ").font(.system(size: 13)).foregroundStyle(Theme.sub)
                    }
                }
                .padding(.vertical, 6)

                switch viewModel.phase {
                case .choosing, .failed:
                    reasons
                    if case let .failed(message) = viewModel.phase {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 13))
                            .padding(12)
                            .background(Theme.amberSoft, in: .rect(cornerRadius: 14))
                    }
                case .resplitting:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("カジリが、もっと小さくかじっています…").font(.system(size: 14))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: .rect(cornerRadius: 18))
                case let .resplit(result):
                    ResplitPreview(original: step, result: result)
                    Button("この小ささならいける") {
                        viewModel.accept(step, useCase: useCase)
                        onClose(true)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(16)
        }
        .background(Theme.ground)
    }

    private var reasons: some View {
        VStack(spacing: 8) {
            ReasonButton(title: "まだ大きい", detail: "もっと小さくかじる", symbol: "arrow.down.right.and.arrow.up.left") {
                Task { await viewModel.resplit(step, useCase: useCase) }
            }
            ReasonButton(title: "いまじゃない", detail: "明日また、今日の薪に出す", symbol: "clock") {
                useCase.postpone(step, now: AppClock.now)
                onClose(true)
            }
            ReasonButton(title: "気が乗らない・頼みたい", detail: "仲間に頼む側へ回す", symbol: "person.2") {
                useCase.handOff(step)
                onClose(true)
            }
            ReasonButton(title: "やらなくていい", detail: "川に流す（下流に残しておく）", symbol: "water.waves") {
                useCase.drop(step)
                onClose(true)
            }
        }
    }
}

private struct ReasonButton: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(Theme.chip, in: .rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .heavy))
                    Text(detail).font(.system(size: 12)).foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .background(Theme.card, in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}

/// 割り直した結果（元の薪に線を引いて、新しい小さい薪を並べる）
private struct ResplitPreview: View {
    let original: Step
    let result: ResplitResult

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("こうかじり直した").font(.system(size: 12, weight: .heavy))
            Text("\(original.title)　\(original.minutes)分")
                .font(.system(size: 13))
                .strikethrough()
                .foregroundStyle(Theme.sub)
            ForEach(Array(result.steps.enumerated()), id: \.offset) { _, piece in
                HStack {
                    Text(piece.title).font(.system(size: 15, weight: .bold))
                    Spacer()
                    Text("\(piece.minutes)分")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.ink, in: .capsule)
                }
            }
            Text(result.comment).font(.system(size: 13)).foregroundStyle(Theme.sub)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }
}

#if DEBUG
#Preview("理由を選ぶ") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    LaterSheet(step: useCase.allSteps().first { $0.owner == .me }!) { _ in }
        .environment(useCase)
        .modelContainer(container)
}
#endif

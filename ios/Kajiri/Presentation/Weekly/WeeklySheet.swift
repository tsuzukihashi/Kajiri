import SwiftUI

/// 週のふりかえり。片づけた薪の数と曜日ごとの棒、カジリの【よかったところ】【次の一歩】【今日のひとこと】
struct WeeklySheet: View {
    @Environment(LogUseCase.self) private var useCase
    @State private var viewModel = WeeklyViewModel(now: AppClock.now)

    var body: some View {
        let summary = viewModel.summary(useCase: useCase)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(summary)
                countCard(summary)
                review(summary)
                Text("ふりかえりは、片づけた薪の名前と数だけをカジリに送って書いてもらいます。")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.sub)
            }
            .padding(18)
        }
        .background(Theme.ground)
        .onAppear { viewModel.load(useCase: useCase) }
    }

    private func header(_ summary: WeekSummary) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("週のふりかえり").font(.system(size: 26, weight: .black))
                Text(summary.rangeText).font(.system(size: 14, weight: .bold)).foregroundStyle(Theme.sub)
            }
            Spacer()
            Button { viewModel.move(-1, useCase: useCase, now: AppClock.now) } label: {
                Image(systemName: "chevron.left").frame(width: 40, height: 40).background(Theme.chip, in: .circle)
            }
            .accessibilityLabel(Text("前の週"))
            Button { viewModel.move(1, useCase: useCase, now: AppClock.now) } label: {
                Image(systemName: "chevron.right").frame(width: 40, height: 40).background(Theme.chip, in: .circle)
            }
            .disabled(!viewModel.canMoveForward(now: AppClock.now))
            .opacity(viewModel.canMoveForward(now: AppClock.now) ? 1 : 0.3)
            .accessibilityLabel(Text("次の週"))
        }
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(Theme.ink)
    }

    private func countCard(_ summary: WeekSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("片づけた薪").font(.system(size: 13)).foregroundStyle(Theme.sub)
                Text("\(summary.done.count)").font(.system(size: 40, weight: .black))
                Text("本").font(.system(size: 14, weight: .bold))
                Spacer()
                if summary.kajiriDone > 0 {
                    Text("カジリが作った分 \(summary.kajiriDone)本")
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Theme.amberSoft, in: .capsule)
                }
            }
            WeekBars(days: summary.days)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func review(_ summary: WeekSummary) -> some View {
        switch viewModel.phase {
        case .idle:
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    KajiriImage(pose: .think, size: 48)
                    Text(summary.isEmpty
                         ? String(localized: "この週は、まだ記録がないな。それでも、ひとこと書いておこうか。")
                         : String(localized: "この週の薪を、いっしょに見返そうか。"))
                        .font(.system(size: 14, weight: .bold))
                }
                Button("カジリにふりかえってもらう") {
                    Task { await viewModel.write(useCase: useCase) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(16)
            .background(Theme.card, in: .rect(cornerRadius: 20))
        case .writing:
            HStack(spacing: 10) {
                ProgressView()
                Text("カジリが書いています…").font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .background(Theme.card, in: .rect(cornerRadius: 20))
        case let .failed(message):
            VStack(alignment: .leading, spacing: 10) {
                Label(message, systemImage: "exclamationmark.triangle").font(.system(size: 13))
                Button("もう一度たのむ") {
                    Task { await viewModel.write(useCase: useCase) }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .padding(16)
            .background(Theme.amberSoft, in: .rect(cornerRadius: 20))
        case let .written(result):
            ReviewCard(title: "よかったところ", text: result.good, isAccent: false)
            ReviewCard(title: "次の一歩", text: result.next, isAccent: false)
            ReviewCard(title: "今日のひとこと", text: result.word, isAccent: true)
        }
    }
}

/// ふりかえりの1欄
private struct ReviewCard: View {
    let title: LocalizedStringKey
    let text: String
    let isAccent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if isAccent {
                KajiriImage(pose: .face, size: 36)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.sub)
                Text(text).font(.system(size: isAccent ? 18 : 15, weight: isAccent ? .heavy : .bold))
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(isAccent ? Theme.amberSoft : Theme.card, in: .rect(cornerRadius: 20))
    }
}

#if DEBUG
#Preview("記録がある週") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    WeeklySheet()
        .environment(useCase)
        .modelContainer(container)
}

#Preview("記録がない週") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    WeeklySheet()
        .environment(useCase)
        .modelContainer(container)
}
#endif

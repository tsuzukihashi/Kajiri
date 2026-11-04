import SwiftUI
import UIKit

/// カジリが運んできたもの（下書き・調べもの・一覧）を受け取る。見て、押すだけ
struct HandoffView: View {
    let stepID: UUID

    @Environment(LogUseCase.self) private var useCase
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        Group {
            if let step = useCase.step(id: stepID) {
                content(step)
            } else {
                ContentUnavailableView("この薪は見つかりませんでした", systemImage: "questionmark", description: Text("割り直されたか、片づいたのかもしれません。"))
            }
        }
        .background(Theme.ground)
    }

    private func content(_ step: Step) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    KajiriImage(pose: step.workState == .ready ? .hand : .gnaw, size: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        if let log = step.log {
                            Text("丸太: \(log.title)").font(.system(size: 12)).foregroundStyle(Theme.sub)
                        }
                        Text(PlainText.clean(step.workTitle ?? step.title)).font(.system(size: 20, weight: .heavy))
                        Text(statusText(step)).font(.system(size: 13)).foregroundStyle(Theme.sub)
                    }
                }
                switch step.workState {
                case .idle, .working:
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("カジリが作っています。ほかの薪を片づけていて大丈夫です。").font(.system(size: 14))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card, in: .rect(cornerRadius: 18))
                case .ready:
                    readyContent(step)
                case .failed:
                    VStack(alignment: .leading, spacing: 10) {
                        Text(step.workBody ?? String(localized: "うまく作れませんでした。"))
                            .font(.system(size: 14))
                        Button("もう一度たのむ") {
                            Task { await useCase.runWork(step, now: AppClock.now) }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(16)
                    .background(Theme.amberSoft, in: .rect(cornerRadius: 18))
                }
            }
            .padding(16)
        }
    }

    private func readyContent(_ step: Step) -> some View {
        // 前の版で保存した下書きに Markdown が残っていても、記号を見せない
        let body = PlainText.clean(step.workBody ?? "")
        return VStack(alignment: .leading, spacing: 12) {
            Text(body)
                .font(.system(size: 15))
                .lineSpacing(4)
                .textSelection(.enabled)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: .rect(cornerRadius: 18))
            HStack(spacing: 10) {
                Button(copied ? "コピーしました" : "コピーする") {
                    UIPasteboard.general.string = body
                    copied = true
                }
                .buttonStyle(SecondaryButtonStyle())
                ShareLink(item: body) {
                    Label("送る・使う", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.chip, in: .rect(cornerRadius: 14))
                }
            }
            Button("受け取った（済みにする）") {
                useCase.complete(step, now: AppClock.now)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func statusText(_ step: Step) -> String {
        switch step.workState {
        case .idle, .working: String(localized: "カジリの番")
        case .ready: String(localized: "見て、よければ使うだけ")
        case .failed: String(localized: "カジリがつまずきました")
        }
    }
}

#if DEBUG
#Preview("運んできた") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let step = useCase.allSteps().first { $0.owner == .kajiri }!
    step.workState = .ready
    step.workTitle = "確定申告で使う書類の一覧"
    step.workBody = "・源泉徴収票\n・医療費の領収書\n・マイナンバーカード"
    return NavigationStack { HandoffView(stepID: step.uuid) }
        .environment(useCase)
        .modelContainer(container)
}
#endif

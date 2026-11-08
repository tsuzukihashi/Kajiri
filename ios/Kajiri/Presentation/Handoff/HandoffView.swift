import SwiftUI
import UIKit

/// カジリから届いたもの（下書き・調べもの・一覧）を受け取る。見て、押すだけ
struct HandoffView: View {
    let stepID: UUID

    @Environment(LogUseCase.self) private var useCase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.columnLayout) private var columns
    @State private var copied = false
    /// 書いているメモの欄（「受け取った」やスクロールで下げる）
    @FocusState private var focusedNote: String?

    var body: some View {
        Group {
            if let step = useCase.step(id: stepID) {
                content(step)
            } else {
                ContentUnavailableView("この薪は見つかりませんでした", systemImage: "questionmark", description: Text("割り直されたか、片づいたのかもしれません。"))
            }
        }
        .background(Theme.ground)
        // 届いたもの1つを受け取る画面なので、タブを隠して「受け取った」を下に隠さない
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ step: Step) -> some View {
        Group {
            switch columns {
            case .single:
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        header(step)
                        if step.workState == .ready {
                            if let progress = checklistProgress(step) { progress }
                            readyBody(step)
                            readyActions(step)
                        } else {
                            stateContent(step)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
            case let .split(leading, gutter):
                // 横に広い画面: 左にだれが何を作ったかと押すところ、右に作ったもの
                HStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header(step)
                            if step.workState == .ready {
                                if let progress = checklistProgress(step) { progress }
                                readyActions(step)
                            } else {
                                Text("見て、よければ使うだけ。合わなければ、使わなくて大丈夫です。")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.sub)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                    }
                    .frame(width: leading)
                    Color.clear.frame(width: gutter)
                    ScrollView {
                        Group {
                            if step.workState == .ready {
                                readyBody(step)
                            } else {
                                stateContent(step)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        // メモの欄の外を押したら、キーボードを下げる
        .contentShape(Rectangle())
        .onTapGesture { focusedNote = nil }
    }

    private func header(_ step: Step) -> some View {
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
    }

    /// 届く前・つまずいたとき
    @ViewBuilder
    private func stateContent(_ step: Step) -> some View {
        switch step.workState {
        case .idle, .working:
            HStack(spacing: 10) {
                ProgressView()
                Text("カジリが作っています。ほかの薪を片づけていて大丈夫です。").font(.system(size: 14))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: .rect(cornerRadius: 18))
        case .ready:
            EmptyView()
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

    /// 前の版で保存した下書きに Markdown が残っていても、記号を見せない
    private func cleanBody(_ step: Step) -> String {
        PlainText.clean(step.workBody ?? "")
    }

    /// チェックリストなら「何項目のうちいくつ確かめたか」
    private func checklistProgress(_ step: Step) -> WorkChecklistProgress? {
        let document = WorkDocument.parse(cleanBody(step))
        guard document.hasChecklist else { return nil }
        let progress = useCase.workProgress(of: step)
        return WorkChecklistProgress(checked: progress.checkedCount(in: document), total: document.checkIDs.count)
    }

    /// カジリが作ったもの。一覧は項目ごとに分けて見せ（チェックリストなら押してチェックでき、メモを書きこめる）、
    /// メールの下書きのような地の文は、送る形のまま見せる
    @ViewBuilder
    private func readyBody(_ step: Step) -> some View {
        let body = cleanBody(step)
        let document = WorkDocument.parse(body)
        if document.isStructured {
            WorkChecklistView(
                document: document,
                progress: useCase.workProgress(of: step),
                onToggle: { useCase.toggleCheck(step, id: $0) },
                onNote: { useCase.setNote(step, id: $0, text: $1) },
                focusedNote: $focusedNote
            )
        } else {
            SectionBox(title: "カジリが作ったもの", detail: nil) {
                Text(body)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// コピー・送る・受け取った。一覧は、チェック・メモ・選んだものを入れた形で渡す
    private func readyActions(_ step: Step) -> some View {
        let body = cleanBody(step)
        let document = WorkDocument.parse(body)
        let text = document.isStructured ? document.exportText(progress: useCase.workProgress(of: step)) : body
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button(copied ? "コピーしました" : "コピーする") {
                    focusedNote = nil
                    UIPasteboard.general.string = text
                    copied = true
                }
                .buttonStyle(SecondaryButtonStyle())
                ShareLink(item: text) {
                    Label("送る・使う", systemImage: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Theme.chip, in: .rect(cornerRadius: 14))
                }
            }
            Button("受け取った") {
                focusedNote = nil
                useCase.complete(step, now: AppClock.now)
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    private func statusText(_ step: Step) -> String {
        switch step.workState {
        case .idle, .working: String(localized: "カジリの番")
        case .ready:
            WorkDocument.parse(cleanBody(step)).hasChecklist
                ? String(localized: "押してチェックしながら使う")
                : String(localized: "見て、よければ使うだけ")
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

#Preview("前の版の長い手続きの並び") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let step = useCase.allSteps().first { $0.owner == .kajiri }!
    step.workState = .ready
    step.workTitle = "住所変更の手続き一覧（期限の目安つき）"
    step.workBody = StoreShots.longProcedureSample
    return NavigationStack { HandoffView(stepID: step.uuid) }
        .environment(useCase)
        .modelContainer(container)
}

#Preview("チェックリストが届いた") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let step = useCase.allSteps().first { $0.owner == .kajiri }!
    step.workState = .ready
    step.workTitle = "木工事完了の立会いで使うチェックリスト"
    step.workBody = "【1 物干し竿】\n見る場所\n□ 物干し金物をつける位置\n□ 竿の長さが入る幅があるか\n聞くこと\n□ 金物はいつ、誰がつけるか\nメモ：\n【2 住所変更】\n□ 表札・ポストをつける位置"
    return NavigationStack { HandoffView(stepID: step.uuid) }
        .environment(useCase)
        .modelContainer(container)
}
#endif

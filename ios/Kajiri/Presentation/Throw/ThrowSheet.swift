import SwiftUI

/// 丸太を投げるシート。上半分が黒い帯で、下にメモと「カジリにかじってもらう」。
/// 渡すと、同じシートの中で分解の結果に切りかわる（独立したモーダルの流れ）。
struct ThrowSheet: View {
    @Environment(LogUseCase.self) private var useCase
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ThrowViewModel
    @FocusState private var isMemoFocused: Bool

    init(request: ThrowRequest) {
        _viewModel = State(initialValue: ThrowViewModel(memo: request.memo, sourceEventID: request.sourceEventID))
    }

    var body: some View {
        switch viewModel.phase {
        case .editing, .splitting, .failed:
            editor
        case let .result(result):
            SplitResultView(
                result: result,
                onBack: { viewModel.backToEditing() },
                onAccept: {
                    viewModel.save(useCase: useCase)
                    dismiss()
                }
            )
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            ThrowHeader(
                isSplitting: viewModel.phase == .splitting,
                canSplit: viewModel.canSplit,
                onClose: {
                    isMemoFocused = false
                    dismiss()
                },
                onSplit: {
                    isMemoFocused = false
                    Task { await viewModel.split(useCase: useCase) }
                }
            )
            ScrollView {
                VStack(spacing: 10) {
                    memoCard
                    if viewModel.phase == .splitting {
                        SplittingCard()
                    }
                    if case let .failed(message) = viewModel.phase {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.amberSoft, in: .rect(cornerRadius: 18))
                    }
                    ShareHintRow()
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(Rectangle())
            .onTapGesture { isMemoFocused = false }
        }
        .background(Theme.ground)
        .interactiveDismissDisabled(viewModel.phase == .splitting)
        .onAppear { isMemoFocused = true }
    }

    private var memoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("気になってること、そのまま。整えなくていい")
                .font(.system(size: 12))
                .foregroundStyle(Theme.sub)
            TextEditor(text: $viewModel.memo)
                .focused($isMemoFocused)
                .font(.system(size: 16))
                .frame(minHeight: 150)
                .scrollContentBackground(.hidden)
                .overlay(alignment: .topLeading) {
                    if viewModel.memo.isEmpty {
                        Text("例: 12月20日に引っ越し。粗大ゴミどうしよう")
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.sub.opacity(0.7))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
                .disabled(viewModel.phase == .splitting)
        }
        .padding(16)
        .background(Theme.card, in: .rect(cornerRadius: 18))
    }
}

#if DEBUG
#Preview("投げる") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    ThrowSheet(request: ThrowRequest(memo: "", sourceEventID: nil))
        .environment(useCase)
        .modelContainer(container)
}

#Preview("予定から投げる") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    ThrowSheet(request: ThrowRequest(memo: "12月20日 引っ越し。荷造りの準備", sourceEventID: "preview"))
        .environment(useCase)
        .modelContainer(container)
}
#endif

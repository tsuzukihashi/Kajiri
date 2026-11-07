import SwiftUI

/// この1本だけ。薪を1本だけ手渡して、それしか見せない
struct FocusView: View {
    let stepID: UUID

    @Environment(LogUseCase.self) private var useCase
    @Environment(\.dismiss) private var dismiss
    @State private var isAskingLater = false

    var body: some View {
        Group {
            if let step = useCase.step(id: stepID) {
                content(step)
            } else {
                ContentUnavailableView("この薪は見つかりませんでした", systemImage: "questionmark", description: Text("割り直されたか、片づいたのかもしれません。"))
            }
        }
        .background(Theme.ground)
        // 薪1本だけを見せる画面なので、タブも隠す
        .toolbar(.hidden, for: .tabBar)
    }

    private func content(_ step: Step) -> some View {
        VStack(spacing: 4) {
            if let log = step.log {
                Text("丸太: \(log.title)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 8)
            KajiriBubble(text: String(localized: "これだけ持って。ほかは、おれが持ってる。"))
            KajiriImage(pose: .hand, size: 210)
            FocusCard(step: step)
                .padding(.top, 10)
            Spacer(minLength: 8)
            VStack(spacing: 8) {
                Button("できた") {
                    useCase.complete(step, now: AppClock.now)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                Button("あとで") { isAskingLater = true }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .onAppear { useCase.start(step, now: AppClock.now) }
        .sheet(isPresented: $isAskingLater) {
            LaterSheet(step: step) { closesFocus in
                isAskingLater = false
                if closesFocus { dismiss() }
            }
            .presentationDetents([.fraction(0.62), .large])
        }
    }
}

/// 手渡す薪の中身
struct FocusCard: View {
    let step: Step

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.title)
                .font(.system(size: 22, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Text("\(step.minutes)分")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.ink, in: .capsule)
                if step.needsComputer {
                    Label("パソコン", systemImage: "laptopcomputer")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.chip, in: .capsule)
                }
            }
            if !step.firstMotion.isEmpty {
                Text("最初の動き: \(step.firstMotion)")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: .rect(cornerRadius: 20))
    }
}

#if DEBUG
#Preview("この1本だけ") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let step = useCase.allSteps().first { $0.owner == .me }!
    NavigationStack {
        FocusView(stepID: step.uuid)
    }
    .environment(useCase)
    .modelContainer(container)
}

#Preview("見つからない") {
    let (useCase, container) = LogUseCase.preview(filled: false)
    FocusView(stepID: UUID())
        .environment(useCase)
        .modelContainer(container)
}
#endif

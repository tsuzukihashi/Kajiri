import SwiftUI

/// カジリの薪を1つの箱にまとめる。届いたもの・つまずいたものは押せる行、作っているものは最後に件数だけ
struct KajiriInboxCard: View {
    let steps: [Step]

    var body: some View {
        let ready = steps.filter { $0.workState == .ready || $0.workState == .failed }
        let working = steps.filter { $0.workState == .idle || $0.workState == .working }
        SectionBox(
            title: ready.isEmpty ? "カジリが作っています" : "カジリから届いた",
            detail: ready.isEmpty ? nil : String(localized: "\(ready.count)件")
        ) {
            BoxRows(items: ready) { step in
                NavigationLink(value: Route.handoff(step.uuid)) {
                    InboxRow(step: step)
                }
                .buttonStyle(.plain)
            }
            if !working.isEmpty {
                if !ready.isEmpty { BoxDivider() }
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 26)
                    Text(ready.isEmpty ? "\(working.count)件、できたらここに届きます" : "ほか\(working.count)件を作っています")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.sub)
                    Spacer(minLength: 0)
                }
                .padding(14)
            }
        }
    }
}

/// 届いたもの1件。左の琥珀色の印で、カジリが作ったものだと分かる
private struct InboxRow: View {
    let step: Step

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: step.workState == .failed ? "exclamationmark.triangle.fill" : "doc.text.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.ink)
                .frame(width: 26, height: 26)
                .background(Theme.amber, in: .rect(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(PlainText.clean(step.workTitle ?? step.title))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                Text(step.workState == .failed ? "つまずきました。もう一度たのめます" : "見て、よければ使うだけ")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.line)
        }
        .padding(14)
        .contentShape(Rectangle())
    }
}

#if DEBUG
#Preview("届いた・作っている") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps().filter { $0.owner == .kajiri }
    if let first = steps.first {
        first.workState = .ready
        first.workTitle = "確定申告で使う書類の一覧"
    }
    return NavigationStack {
        KajiriInboxCard(steps: steps).padding().background(Theme.ground)
    }
    .modelContainer(container)
}

#Preview("作っているだけ") {
    let (useCase, container) = LogUseCase.preview(filled: true)
    let steps = useCase.allSteps().filter { $0.owner == .kajiri }
    steps.forEach { $0.workState = .working }
    return NavigationStack {
        KajiriInboxCard(steps: steps).padding().background(Theme.ground)
    }
    .modelContainer(container)
}
#endif

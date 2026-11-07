import SwiftUI

/// カジリの薪を1か所にまとめる。届いたもの・つまずいたものは押せる行、作っているものは件数だけ
struct KajiriInboxCard: View {
    let steps: [Step]

    var body: some View {
        let ready = steps.filter { $0.workState == .ready || $0.workState == .failed }
        let working = steps.filter { $0.workState == .idle || $0.workState == .working }
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                KajiriImage(pose: .face, size: 28)
                Text(ready.isEmpty ? "カジリが作っています" : "カジリから届いた")
                    .font(.system(size: 15, weight: .heavy))
                if !ready.isEmpty {
                    Text("\(ready.count)")
                        .font(.system(size: 12, weight: .heavy))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.amber, in: .capsule)
                }
            }
            ForEach(ready) { step in
                NavigationLink(value: Route.handoff(step.uuid)) {
                    HStack(spacing: 10) {
                        Image(systemName: step.workState == .failed ? "exclamationmark.triangle" : "doc.text")
                            .font(.system(size: 15))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(PlainText.clean(step.workTitle ?? step.title))
                                .font(.system(size: 15, weight: .bold))
                                .multilineTextAlignment(.leading)
                            Text(step.workState == .failed ? "つまずきました。もう一度たのめます" : "見て、よければ使うだけ")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.sub)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.sub)
                    }
                    .foregroundStyle(Theme.ink)
                    .padding(12)
                    .background(.white, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            if !working.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(ready.isEmpty ? "\(working.count)件、できたらここに届きます" : "ほか\(working.count)件を作っています")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.amberSoft, in: .rect(cornerRadius: 20))
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

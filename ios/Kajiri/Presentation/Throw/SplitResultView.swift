import SwiftUI

/// カジリがかじった結果。薪が「誰がやるか」の印つきで並ぶ
struct SplitResultView: View {
    let result: DecomposeResult
    let placement: EventPlacement
    let onUndo: (PlacedEvent) -> Void
    let onBack: () -> Void
    let onAccept: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.sectionSpacing) {
                    if !placement.isEmpty {
                        PlacedEventsCard(placement: placement, onUndo: onUndo)
                    }
                    ForEach(groups, id: \.title) { group in
                        SectionBox(titleText: Text(group.title), detail: String(localized: "\(group.steps.count)本")) {
                            ForEach(Array(group.steps.enumerated()), id: \.offset) { index, step in
                                if index > 0 { BoxTextDivider() }
                                StepRow(step: step)
                            }
                        }
                    }
                    if !result.why.isEmpty {
                        Label(result.why, systemImage: "sparkles")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            HStack(spacing: 10) {
                Button("書き直す", action: onBack).buttonStyle(SecondaryButtonStyle())
                Button(result.steps.isEmpty ? "閉じる" : "これでいこう", action: onAccept).buttonStyle(PrimaryButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
            .background(Theme.ground.shadow(.drop(color: .black.opacity(0.06), radius: 6, y: -3)))
        }
        .background(Theme.ground)
    }

    /// 誰がやるかで分けた薪（それぞれの中は、かじった順のまま）
    private var groups: [(title: String, steps: [StepDTO])] {
        func owner(_ step: StepDTO) -> StepOwner { StepOwner(rawValue: step.owner) ?? .me }
        let all: [(String, [StepDTO])] = [
            (String(localized: "じぶんの薪"), result.steps.filter { owner($0) == .me }),
            (String(localized: "カジリがやる"), result.steps.filter { owner($0) == .kajiri }),
            (String(localized: "頼む・待ち"), result.steps.filter { owner($0) == .other || owner($0) == .wait }),
        ]
        return all.filter { !$0.1.isEmpty }.map { (title: $0.0, steps: $0.1) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer()
                if let deadline = JapanDate.date(day: result.deadline) {
                    Text("\(deadline, format: .dateTime.month().day())まで")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.amber, in: .capsule)
                }
            }
            HStack(spacing: 14) {
                KajiriImage(pose: .gnaw, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.steps.isEmpty ? "· 予定" : "· 丸太").font(.system(size: 12)).foregroundStyle(Color(white: 0.68))
                    Text(result.logTitle).font(.system(size: 22, weight: .heavy)).foregroundStyle(.white)
                    Text(result.comment).font(.system(size: 13)).foregroundStyle(Color(white: 0.9))
                }
            }
        }
        .padding(16)
        .padding(.top, 8)
        .background(Theme.ink)
    }
}

#if DEBUG
#Preview("薪だけ") {
    SplitResultView(result: .sampleTax, placement: .empty, onUndo: { _ in }, onBack: {}, onAccept: {})
}

#Preview("予定と薪") {
    SplitResultView(result: .sampleTax, placement: .sampleAdded, onUndo: { _ in }, onBack: {}, onAccept: {})
}

#Preview("予定だけ") {
    SplitResultView(result: .sampleDentist, placement: .sampleAdded, onUndo: { _ in }, onBack: {}, onAccept: {})
}

#Preview("許可が無い") {
    SplitResultView(result: .sampleDentist, placement: .sampleNeedsAccess, onUndo: { _ in }, onBack: {}, onAccept: {})
}
#endif
